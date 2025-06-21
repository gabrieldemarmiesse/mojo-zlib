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
)
from .zlib_shared_object import get_zlib_dl_handle


fn decompress(
    data: Span[Byte], /, wbits: Int = MAX_WBITS, bufsize: Int = DEF_BUF_SIZE
) raises -> List[Byte]:
    """Decompress deflated data using zlib decompression.

    Args:
        data: The compressed data to decompress.
        wbits: Window bits parameter controlling format and window size
               - Positive values (9-15): zlib format with header and trailer
               - Negative values (-9 to -15): raw deflate format
               - Values 25-31: gzip format.
        bufsize: Initial size of the output buffer.

    Returns:
        The decompressed data.
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


fn decompressobj(wbits: Int = MAX_WBITS) raises -> Decompress:
    """Return a decompression object.

    This function creates and returns a decompression object that can be used
    to decompress data incrementally. This matches Python's zlib.decompressobj() API.

    Args:
        wbits: Window bits parameter controlling format and window size
               - Positive values (9-15): zlib format with header and trailer
               - Negative values (-9 to -15): raw deflate format
               - Values 25-31: gzip format.

    Returns:
        A Decompress object that can decompress data incrementally.

    Example:
        ```mojo
        var decomp = zlib.decompressobj()
        var result1 = decomp.decompress(data_chunk1)
        var result2 = decomp.decompress(data_chunk2)
        var final = decomp.flush()
        ```
    """
    return Decompress(wbits)


struct Decompress(Copyable, Movable):
    """A streaming decompressor that can decompress data in chunks to avoid large memory usage.

    This struct matches Python's zlib decompression object API.
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
    var wbits: Int

    fn __init__(out self, wbits: Int = MAX_WBITS) raises:
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
        self.output_buffer = List[UInt8](capacity=65536)
        self.output_buffer.resize(65536, 0)
        self.output_pos = 0
        self.output_available = 0
        self.wbits = wbits

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
            Int32(self.wbits),
            zlib_version.unsafe_cstr_ptr().bitcast[UInt8](),
            Int32(sys.sizeof[ZStream]()),
        )

        if init_res != Z_OK:
            log_zlib_result(init_res, compressing=False)

        self.initialized = True

    fn __copyinit__(out self, existing: Self):
        """Copy constructor - creates a fresh decompressor."""
        # Since copying mid-stream state is complex, just create a fresh instance
        self.handle = existing.handle  # Share the same DLHandle
        self.inflate_fn = existing.inflate_fn
        self.inflateEnd = existing.inflateEnd

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
        self.output_buffer = List[UInt8](capacity=65536)
        self.output_buffer.resize(65536, 0)
        self.output_pos = 0
        self.output_available = 0
        self.wbits = existing.wbits

    fn __moveinit__(out self, owned existing: Self):
        """Move constructor."""
        self.stream = existing.stream
        self.handle = existing.handle
        self.inflate_fn = existing.inflate_fn
        self.inflateEnd = existing.inflateEnd
        self.initialized = existing.initialized
        self.finished = existing.finished
        self.input_buffer = existing.input_buffer^
        self.output_buffer = existing.output_buffer^
        self.output_pos = existing.output_pos
        self.output_available = existing.output_available
        self.wbits = existing.wbits

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
        elif result != Z_OK:
            log_zlib_result(result, compressing=False)

        # Calculate how much output was produced
        self.output_available = len(self.output_buffer) - Int(
            self.stream.avail_out
        )

        # Remove consumed input
        var consumed = len(self.input_buffer) - Int(self.stream.avail_in)
        if consumed > 0:
            var new_input = List[UInt8]()
            for i in range(consumed, len(self.input_buffer)):
                new_input.append(self.input_buffer[i])
            self.input_buffer = new_input^

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
        """Decompress data incrementally.

        This method matches Python's zlib decompression object API.

        Args:
            data: Compressed data to decompress.
            max_length: Maximum number of bytes to return. -1 means no limit.

        Returns:
            Decompressed data as List[UInt8].
        """
        if len(data) > 0:
            self.feed_input(data)

        if max_length == -1:
            # Return all available data
            var result = List[UInt8]()
            while True:
                var chunk = self.read(65536)  # Read in 64KB chunks
                if len(chunk) == 0:
                    break
                result += chunk
            return result
        else:
            # Return up to max_length bytes
            return self.read(max_length)

    fn flush(mut self) raises -> List[UInt8]:
        """Flush any remaining data.

        This method matches Python's zlib decompression object API.
        Returns any remaining decompressed data.

        Returns:
            Any remaining decompressed data as List[UInt8].
        """
        var result = List[UInt8]()
        while not self.is_finished():
            var chunk = self.read(65536)  # Read in 64KB chunks
            if len(chunk) == 0:
                break
            result += chunk
        return result

    fn copy(self) raises -> Decompress:
        """Create a copy of the decompressor.

        This method matches Python's zlib decompression object API.
        Note: This creates a fresh decompressor since copying mid-stream state is complex.

        Returns:
            A new Decompress object with the same configuration.
        """
        return Decompress(self.wbits)

    fn __del__(owned self):
        if self.initialized:
            _ = self.inflateEnd(UnsafePointer(to=self.stream))
