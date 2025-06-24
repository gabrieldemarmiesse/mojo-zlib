from sys import ffi
from memory import memset_zero, UnsafePointer
from sys import info, exit
import sys
import os
from .constants import (
    ZStream,
    Bytef,
    z_stream_ptr,
    inflateInit2_type,
    inflate_type,
    inflateEnd_type,
    deflateInit2_type,
    deflate_type,
    deflateEnd_type,
    Z_OK,
    Z_STREAM_END,
    Z_NO_FLUSH,
    Z_FINISH,
    Z_DEFAULT_COMPRESSION,
    Z_BEST_COMPRESSION,
    Z_BEST_SPEED,
    Z_DEFLATED,
    Z_DEFAULT_STRATEGY,
    MAX_WBITS,
    DEF_BUF_SIZE,
    log_zlib_result,
    BUFFER_SIZE,
)
from .zlib_shared_object import get_zlib_dl_handle


fn decompress(
    data: Span[Byte], /, wbits: Int32 = MAX_WBITS, bufsize: Int = DEF_BUF_SIZE
) raises -> List[Byte]:
    """Decompresses the bytes in data, returning a bytes object containing the uncompressed data.

    Args:
        data: The compressed data to decompress.
        wbits: Window bits parameter controlling the compression format and window size:
               - 9 to 15: zlib format with header and checksum
               - -9 to -15: raw deflate format without header or checksum
               - 16 + (9 to 15): gzip format with header and checksum
               - Values 32-47: automatic header detection (zlib or gzip)
        bufsize: Initial size of the output buffer used to hold decompressed data.
                 The default size is 16384.

    Returns:
        The decompressed data as List[Byte].

    Raises:
        Error: If the compressed data is invalid, corrupted, or incomplete.
    """
    if len(data) == 0:
        raise Error("Cannot decompress empty data")
    var decompressor = Decompress(wbits)
    decompressor.feed_input(data)

    var result = List[UInt8]()
    result.reserve(bufsize)

    # Read all available data in chunks
    while not decompressor.is_finished():
        var chunk = decompressor.read(min(bufsize, 65536))
        if len(chunk) == 0:
            break
        result += chunk

    return result


fn decompressobj(wbits: Int32 = MAX_WBITS) raises -> Decompress:
    """Return a decompression object whose decompress() method takes a bytes object
    and returns decompressed data for a portion of the data.

    The returned object also has decompress() and flush() methods, and unused_data
    and unconsumed_tail attributes. See below for their descriptions.
    This allows for incremental decompression when decompressing very large amounts of data.

    Args:
        wbits: Window bits parameter controlling the compression format and window size:
               - 9 to 15: zlib format with header and checksum
               - -9 to -15: raw deflate format without header or checksum
               - 16 + (9 to 15): gzip format with header and checksum
               - Values 32-47: automatic header detection (zlib or gzip)

    Returns:
        A Decompress object that can decompress data incrementally.

    Raises:
        Error: If decompression initialization fails or invalid parameters are provided.
    """
    return Decompress(wbits)


struct Decompress(Movable):
    """A decompression object for decompressing data incrementally.

    Allows decompression of data that cannot fit into memory all at once.
    The object can be used to decompress data piece by piece.
    Contains attributes unused_data, unconsumed_tail, and eof that provide
    information about the decompression process.
    """

    var stream: ZStream
    var handle: ffi.DLHandle
    var inflate_fn: fn (strm: z_stream_ptr, flush: ffi.c_int) -> ffi.c_int
    var inflateEnd: fn (strm: z_stream_ptr) -> ffi.c_int
    var initialized: Bool
    var finished: Bool
    var input_buffer: List[UInt8]
    var output_buffer: List[UInt8]
    var output_pos: Int
    var output_available: Int
    var wbits: Int32

    # Python-compatible attributes
    var unused_data: List[UInt8]
    """A bytes object which contains any bytes past the end of the compressed data.
    That is, if the input data contains compressed data followed by extra data,
    this attribute will contain the extra data. This attribute is always empty
    until the entire compressed stream has been decompressed."""

    var unconsumed_tail: List[UInt8]
    """A bytes object that contains any data that was not consumed by the last
    decompress() call because it exceeded the limit on the uncompressed data.
    This data has not yet been seen by the zlib machinery, so you must feed it
    (possibly with further data concatenated to it) back to a subsequent
    decompress() method call in order to get correct output."""

    var eof: Bool
    """True if the end-of-stream marker has been reached."""

    fn __init__(out self, wbits: Int32 = MAX_WBITS) raises:
        self.handle = get_zlib_dl_handle()
        self.inflate_fn = self.handle.get_function[inflate_type]("inflate")
        self.inflateEnd = self.handle.get_function[inflateEnd_type](
            "inflateEnd"
        )

        self.stream = ZStream(
            next_in=UnsafePointer[Bytef](),
            avail_in=0,
            total_in=0,
            next_out=UnsafePointer[Bytef](),
            avail_out=0,
            total_out=0,
            msg=UnsafePointer[UInt8](),
            state=UnsafePointer[UInt8](),
            zalloc=UnsafePointer[UInt8](),
            zfree=UnsafePointer[UInt8](),
            opaque=UnsafePointer[UInt8](),
            data_type=0,
            adler=0,
            reserved=0,
        )

        self.initialized = False
        self.finished = False
        self.input_buffer = List[UInt8]()
        # Use 64KB output buffer to balance memory usage and performance
        self.output_buffer = List[UInt8](capacity=BUFFER_SIZE)
        self.output_buffer.resize(BUFFER_SIZE, 0)
        self.output_pos = 0
        self.output_available = 0
        self.wbits = wbits

        # Initialize Python-compatible attributes
        self.unused_data = List[UInt8]()
        self.unconsumed_tail = List[UInt8]()
        self.eof = False

    fn initialize(mut self) raises:
        """Initialize the zlib stream for decompression."""
        if self.initialized:
            return

        var inflateInit2 = self.handle.get_function[inflateInit2_type](
            "inflateInit2_"
        )
        var zlib_version = String("1.2.11")
        var init_res = inflateInit2(
            UnsafePointer(to=self.stream),
            self.wbits,
            zlib_version.unsafe_cstr_ptr().bitcast[UInt8](),
            Int32(sys.sizeof[ZStream]()),
        )

        if init_res != Z_OK:
            log_zlib_result(init_res, compressing=False)

        self.initialized = True

    fn feed_input(mut self, data: Span[Byte]):
        """Feed compressed input data to the decompressor."""
        for byte in data:
            self.input_buffer.append(byte)

    fn _decompress_available(mut self) raises -> Bool:
        """Try to decompress some data from input buffer. Returns True if output was produced.
        """
        if not self.initialized:
            self.initialize()

        if self.finished or len(self.input_buffer) == 0:
            return False

        # Set up input
        self.stream.next_in = self.input_buffer.unsafe_ptr()
        self.stream.avail_in = UInt32(len(self.input_buffer))

        # Reset output buffer
        self.output_pos = 0
        self.output_available = 0
        self.stream.next_out = self.output_buffer.unsafe_ptr()
        self.stream.avail_out = UInt32(len(self.output_buffer))

        # Decompress
        var result = self.inflate_fn(UnsafePointer(to=self.stream), Z_NO_FLUSH)

        if result == Z_STREAM_END:
            self.finished = True
            self.eof = True
            # Any remaining input becomes unused_data
            if Int(self.stream.avail_in) > 0:
                self.unused_data.clear()
                self.unused_data.extend(
                    self.input_buffer[
                        len(self.input_buffer) - Int(self.stream.avail_in) :
                    ]
                )
        elif result != Z_OK:
            log_zlib_result(result, compressing=False)

        # Calculate how much output was produced
        self.output_available = len(self.output_buffer) - Int(
            self.stream.avail_out
        )

        # Update unconsumed_tail and remove consumed input
        var consumed = len(self.input_buffer) - Int(self.stream.avail_in)

        # Remove consumed input from buffer
        if consumed > 0:
            var new_input = List[UInt8]()
            for i in range(consumed, len(self.input_buffer)):
                new_input.append(self.input_buffer[i])
            self.input_buffer = new_input^

        # unconsumed_tail always contains what's left in input_buffer
        self.unconsumed_tail.clear()
        self.unconsumed_tail.extend(self.input_buffer)

        return self.output_available > 0

    fn read(mut self, size: Int) raises -> List[UInt8]:
        """Read up to 'size' bytes of decompressed data."""
        var result = List[UInt8]()
        var remaining = size

        while remaining > 0:
            # If we have data in output buffer, use it first
            if self.output_available > 0:
                var to_copy = min(remaining, self.output_available)
                for i in range(to_copy):
                    result.append(self.output_buffer[self.output_pos + i])

                self.output_pos += to_copy
                self.output_available -= to_copy
                remaining -= to_copy
                continue

            # Try to decompress more data
            if not self._decompress_available():
                # No more data available
                break

        return result

    fn is_finished(self) -> Bool:
        """Check if decompression is complete."""
        return self.finished and self.output_available == 0

    fn decompress(
        mut self, data: Span[Byte], max_length: Int = -1
    ) raises -> List[UInt8]:
        """Decompress data, returning a bytes object containing uncompressed data
        corresponding to at least part of the data in data.

        This data should be concatenated to the output produced by any preceding
        calls to the decompress() method. Some of the input data may be preserved
        in internal buffers for later processing.

        Args:
            data: Compressed data to decompress.
            max_length: Maximum number of bytes to return. If this parameter is negative
                        (the default), there is no limit on the length of the return value.
                        Otherwise, at most max_length bytes are returned.

        Returns:
            Decompressed data as List[UInt8]. May be empty if input data
            is buffered internally.

        Raises:
            Error: If the data is invalid, corrupted, or incomplete.
        """
        if len(data) > 0:
            self.feed_input(data)
            # Update unconsumed_tail to include new data
            self.unconsumed_tail.extend(data)

        if max_length == -1:
            # Return all available data
            var result = List[UInt8]()
            while True:
                var chunk = self.read(BUFFER_SIZE)  # Read in 64KB chunks
                if len(chunk) == 0:
                    break
                result += chunk
            return result
        else:
            # Return up to max_length bytes
            return self.read(max_length)

    fn flush(mut self) raises -> List[UInt8]:
        """Return a bytes object containing any remaining uncompressed data.

        This method is primarily used to force any remaining uncompressed data
        in internal buffers to be returned. Calling flush() is not normally needed
        as decompress() returns any complete uncompressed data.

        Returns:
            Any remaining decompressed data as List[UInt8].

        Raises:
            Error: If there are issues finalizing the decompression.
        """
        var result = List[UInt8]()
        while not self.is_finished():
            var chunk = self.read(BUFFER_SIZE)  # Read in 64KB chunks
            if len(chunk) == 0:
                break
            result += chunk
        return result

    fn __del__(owned self):
        if self.initialized:
            _ = self.inflateEnd(UnsafePointer(to=self.stream))
