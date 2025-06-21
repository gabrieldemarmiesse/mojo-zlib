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


fn compress(
    data: Span[Byte], /, level: Int = -1, wbits: Int = MAX_WBITS
) raises -> List[Byte]:
    """Compress data using zlib compression.

    This function now uses the Compress struct internally for consistency
    and to eliminate code duplication.

    Args:
        data: The data to compress.
        level: Compression level (0-9, -1 for default).
        wbits: Window bits parameter controlling format and window size
               - Positive values (9-15): zlib format with header and trailer
               - Negative values (-9 to -15): raw deflate format
               - Values 25-31: gzip format.

    Returns:
        Compressed data as List[Byte].
    """
    # Create a compressor object
    var compressor = compressobj(level, wbits)

    # Compress all data and flush
    var compressed_data = compressor.compress(data)
    var final_data = compressor.flush()

    # Combine the results
    return compressed_data + final_data


fn compressobj(level: Int = -1, wbits: Int = MAX_WBITS) raises -> Compress:
    """Return a compression object.

    This function creates and returns a compression object that can be used
    to compress data incrementally. This matches Python's zlib.compressobj() API.

    Args:
        level: Compression level (0-9, -1 for default).
        wbits: Window bits parameter controlling format and window size
               - Positive values (9-15): zlib format with header and trailer
               - Negative values (-9 to -15): raw deflate format
               - Values 25-31: gzip format.

    Returns:
        A Compress object that can compress data incrementally.

    Example:
        ```mojo
        var comp = zlib.compressobj()
        var result1 = comp.compress(data_chunk1)
        var result2 = comp.compress(data_chunk2)
        var final = comp.flush()
        ```
    """
    return Compress(level, wbits)


struct Compress(Copyable, Movable):
    """A streaming compressor that can compress data in chunks.

    This struct matches Python's zlib compression object API.
    """

    var stream: ZStream
    var handle: ffi.DLHandle
    var deflate_fn: fn (strm: z_stream_ptr, flush: ffi.c_int) -> ffi.c_int
    var deflateEnd: fn (strm: z_stream_ptr) -> ffi.c_int
    var initialized: Bool
    var finished: Bool
    var level: Int
    var wbits: Int
    var output_buffer: List[UInt8]

    fn __init__(out self, level: Int = -1, wbits: Int = MAX_WBITS) raises:
        self.handle = get_zlib_dl_handle()
        self.deflate_fn = self.handle.get_function[deflate_type]("deflate")
        self.deflateEnd = self.handle.get_function[deflateEnd_type](
            "deflateEnd"
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
        self.level = level
        self.wbits = wbits
        # Use 64KB output buffer
        self.output_buffer = List[UInt8](capacity=65536)
        self.output_buffer.resize(65536, 0)

    fn initialize(mut self) raises:
        """Initialize the zlib stream for compression."""
        if self.initialized:
            return

        var deflateInit2 = self.handle.get_function[deflateInit2_type](
            "deflateInit2_"
        )
        var zlib_version = String("1.2.11")
        var init_res = deflateInit2(
            UnsafePointer(to=self.stream),
            Int32(self.level),
            Z_DEFLATED,
            Int32(self.wbits),
            8,  # mem_level
            Z_DEFAULT_STRATEGY,
            zlib_version.unsafe_cstr_ptr().bitcast[UInt8](),
            Int32(sys.sizeof[ZStream]()),
        )

        if init_res != Z_OK:
            log_zlib_result(init_res, compressing=True)

        self.initialized = True

    fn __copyinit__(out self, existing: Self):
        """Copy constructor - creates a fresh compressor."""
        # Since copying mid-stream state is complex, just create a fresh instance
        self.handle = existing.handle  # Share the same DLHandle
        self.deflate_fn = existing.deflate_fn
        self.deflateEnd = existing.deflateEnd

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
        self.level = existing.level
        self.wbits = existing.wbits
        self.output_buffer = List[UInt8](capacity=65536)
        self.output_buffer.resize(65536, 0)

    fn __moveinit__(out self, owned existing: Self):
        """Move constructor."""
        self.stream = existing.stream
        self.handle = existing.handle
        self.deflate_fn = existing.deflate_fn
        self.deflateEnd = existing.deflateEnd
        self.initialized = existing.initialized
        self.finished = existing.finished
        self.level = existing.level
        self.wbits = existing.wbits
        self.output_buffer = existing.output_buffer^

    fn compress(mut self, data: Span[Byte]) raises -> List[UInt8]:
        """Compress data incrementally.

        This method matches Python's zlib compression object API.

        Args:
            data: Data to compress.

        Returns:
            Compressed data as List[UInt8].
        """
        if not self.initialized:
            self.initialize()

        if self.finished:
            raise Error("Cannot compress data after flush() has been called")

        if len(data) == 0:
            return List[UInt8]()

        var result = List[UInt8]()

        # Set up input
        self.stream.next_in = data.unsafe_ptr()
        self.stream.avail_in = UInt32(len(data))

        # Compress in chunks
        while self.stream.avail_in > 0:
            self.stream.next_out = self.output_buffer.unsafe_ptr()
            self.stream.avail_out = UInt32(len(self.output_buffer))

            var deflate_result = self.deflate_fn(
                UnsafePointer(to=self.stream), Z_NO_FLUSH
            )

            if deflate_result != Z_OK:
                log_zlib_result(deflate_result, compressing=True)

            # Copy output data
            var output_size = len(self.output_buffer) - Int(
                self.stream.avail_out
            )
            for i in range(output_size):
                result.append(self.output_buffer[i])

        return result

    fn flush(mut self) raises -> List[UInt8]:
        """Flush any remaining data and finish compression.

        This method matches Python's zlib compression object API.
        After calling flush(), no more data can be compressed.

        Returns:
            Final compressed data as List[UInt8].
        """
        if not self.initialized:
            self.initialize()

        if self.finished:
            return List[UInt8]()

        var result = List[UInt8]()

        # Finish compression
        self.stream.avail_in = 0
        self.stream.next_in = UnsafePointer[Bytef]()

        while True:
            self.stream.next_out = self.output_buffer.unsafe_ptr()
            self.stream.avail_out = UInt32(len(self.output_buffer))

            var deflate_result = self.deflate_fn(
                UnsafePointer(to=self.stream), Z_FINISH
            )

            # Copy output data
            var output_size = len(self.output_buffer) - Int(
                self.stream.avail_out
            )
            for i in range(output_size):
                result.append(self.output_buffer[i])

            if deflate_result == Z_STREAM_END:
                self.finished = True
                break
            elif deflate_result != Z_OK:
                log_zlib_result(deflate_result, compressing=True)

        return result

    fn copy(self) raises -> Compress:
        """Create a copy of the compressor.

        This method matches Python's zlib compression object API.
        Note: This creates a fresh compressor since copying mid-stream state is complex.

        Returns:
            A new Compress object with the same configuration.
        """
        return Compress(self.level, self.wbits)

    fn __del__(owned self):
        if self.initialized:
            _ = self.deflateEnd(UnsafePointer(to=self.stream))
