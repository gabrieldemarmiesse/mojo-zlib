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
    DEF_MEM_LEVEL,
    log_zlib_result,
    BUFFER_SIZE,
)
from .zlib_shared_object import get_zlib_dl_handle


fn compress(
    data: Span[Byte], /, level: Int32 = -1, wbits: Int32 = MAX_WBITS
) raises -> List[Byte]:
    """Compresses the bytes in data, returning a `List[UInt8]` containing compressed data.

    Args:
        data: The data to compress.
        level: Compression level from 0 to 9 controlling the compression speed/size tradeoff.
               0 means no compression, 1 is fastest with least compression, 9 is slowest
               with best compression. -1 requests a default compromise between speed and
               compression (currently equivalent to level 6).
        wbits: Window bits parameter controlling the compression format and window size:
               - 9 to 15: zlib format with header and checksum
               - -9 to -15: raw deflate format without header or checksum
               - 16 + (9 to 15): gzip format with header and checksum.

    Returns:
        Compressed data as List[Byte].

    Raises:
        Error: If compression fails or invalid parameters are provided.
    """
    # Create a compressor object
    var compressor = compressobj(level, Z_DEFLATED, wbits)

    # Compress all data and flush
    var compressed_data = compressor.compress(data)
    compressed_data += compressor.flush()

    return compressed_data


fn compressobj(
    level: Int32 = -1,
    method: Int32 = Z_DEFLATED,
    wbits: Int32 = MAX_WBITS,
    memLevel: Int32 = DEF_MEM_LEVEL,
    strategy: Int32 = Z_DEFAULT_STRATEGY,
) raises -> Compress:
    """Return a compression object whose compress() method takes a `Span[UInt8]`
    and returns compressed data for a portion of the data.

    The returned object also has flush() and copy() methods. See below for their descriptions.
    This allows for incremental compression; it can be more efficient when compressing
    very large amounts of data.

    Args:
        level: Compression level from 0 to 9 controlling the compression speed/size tradeoff.
               0 means no compression, 1 is fastest with least compression, 9 is slowest
               with best compression. -1 requests a default compromise between speed and
               compression (currently equivalent to level 6).
        method: The compression algorithm. Currently, the only supported value is DEFLATED.
        wbits: Window bits parameter controlling the compression format and window size:
               - 9 to 15: zlib format with header and checksum
               - -9 to -15: raw deflate format without header or checksum
               - 16 + (9 to 15): gzip format with header and checksum.
        memLevel: Controls the amount of memory used for compression. Valid values are
                  from 1 to 9. Higher values use more memory but are faster and produce
                  smaller output.
        strategy: Used to tune the compression algorithm. Possible values are:
                  Z_DEFAULT_STRATEGY, Z_FILTERED, Z_HUFFMAN_ONLY, Z_RLE, and Z_FIXED.

    Returns:
        A Compress object that can compress data incrementally.

    Raises:
        Error: If compression initialization fails or invalid parameters are provided.
    """
    return Compress(level, method, wbits, memLevel, strategy)


struct Compress(Movable):
    """A compression object for compressing data incrementally.

    Allows compression of data that cannot fit into memory all at once.
    The object can be used to compress data piece by piece and then
    retrieve the compressed data.
    """

    var _stream: ZStream
    var _handle: ffi.DLHandle
    var _deflate_fn: fn (strm: z_stream_ptr, flush: ffi.c_int) -> ffi.c_int
    var _deflateEnd: fn (strm: z_stream_ptr) -> ffi.c_int
    var _initialized: Bool
    var _finished: Bool
    var _level: Int32
    var _method: Int32
    var _wbits: Int32
    var _memLevel: Int32
    var _strategy: Int32
    var _output_buffer: List[UInt8]

    fn __init__(
        out self,
        level: Int32 = -1,
        method: Int32 = Z_DEFLATED,
        wbits: Int32 = MAX_WBITS,
        memLevel: Int32 = DEF_MEM_LEVEL,
        strategy: Int32 = Z_DEFAULT_STRATEGY,
    ) raises:
        self._handle = get_zlib_dl_handle()
        self._deflate_fn = self._handle.get_function[deflate_type]("deflate")
        self._deflateEnd = self._handle.get_function[deflateEnd_type](
            "deflateEnd"
        )

        self._stream = ZStream(
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

        self._initialized = False
        self._finished = False
        self._level = level
        self._method = method
        self._wbits = wbits
        self._memLevel = memLevel
        self._strategy = strategy
        # Use 64KB output buffer
        self._output_buffer = List[UInt8](capacity=BUFFER_SIZE)
        self._output_buffer.resize(BUFFER_SIZE, 0)

    fn _make_sure_initialized(mut self) raises:
        """Initialize the zlib stream for compression."""
        if self._initialized:
            return

        var deflateInit2 = self._handle.get_function[deflateInit2_type](
            "deflateInit2_"
        )
        var zlib_version = String("1.2.11")
        var init_res = deflateInit2(
            UnsafePointer(to=self._stream),
            self._level,
            self._method,
            self._wbits,
            self._memLevel,
            self._strategy,
            zlib_version.unsafe_cstr_ptr().bitcast[UInt8](),
            Int32(sys.sizeof[ZStream]()),
        )

        if init_res != Z_OK:
            log_zlib_result(init_res, compressing=True)

        self._initialized = True

    fn compress(mut self, data: Span[Byte]) raises -> List[UInt8]:
        """Compress data, returning a `List[UInt8]` containing compressed data
        for at least part of the data in data.

        This data should be concatenated to the output produced by any
        preceding calls to the compress() method. Some input may be kept
        in internal buffers for later processing.

        Args:
            data: Data to compress.

        Returns:
            Compressed data as List[UInt8]. May be empty if input data
            is buffered internally.

        Raises:
            Error: If compression fails or flush() has already been called.
        """
        self._make_sure_initialized()

        if self._finished:
            raise Error("Cannot compress data after flush() has been called")

        if len(data) == 0:
            return List[UInt8]()

        var result = List[UInt8]()

        # Set up input
        self._stream.next_in = data.unsafe_ptr()
        self._stream.avail_in = UInt32(len(data))

        # Compress in chunks
        while self._stream.avail_in > 0:
            self._stream.next_out = self._output_buffer.unsafe_ptr()
            self._stream.avail_out = UInt32(len(self._output_buffer))

            var deflate_result = self._deflate_fn(
                UnsafePointer(to=self._stream), Z_NO_FLUSH
            )

            if deflate_result != Z_OK:
                log_zlib_result(deflate_result, compressing=True)

            # Copy output data
            var output_size = len(self._output_buffer) - Int(
                self._stream.avail_out
            )
            for i in range(output_size):
                result.append(self._output_buffer[i])

        return result

    fn flush(mut self) raises -> List[UInt8]:
        """Finish the compression process and return a `List[UInt8]` containing
        any remaining compressed data.

        This method finishes the compression of any data that might remain in the
        internal buffers and returns the final compressed data. After calling
        `flush()`, the compressor object cannot be used again; subsequent calls
        to `compress()` will raise an error.

        Returns:
            Final compressed data as List[UInt8].

        Raises:
            Error: If compression finalization fails.
        """
        self._make_sure_initialized()

        if self._finished:
            return List[UInt8]()

        var result = List[UInt8]()

        # Finish compression
        self._stream.avail_in = 0
        self._stream.next_in = UnsafePointer[Bytef]()

        while True:
            self._stream.next_out = self._output_buffer.unsafe_ptr()
            self._stream.avail_out = UInt32(len(self._output_buffer))

            var deflate_result = self._deflate_fn(
                UnsafePointer(to=self._stream), Z_FINISH
            )

            # Copy output data
            var output_size = len(self._output_buffer) - Int(
                self._stream.avail_out
            )
            for i in range(output_size):
                result.append(self._output_buffer[i])

            if deflate_result == Z_STREAM_END:
                self._finished = True
                break
            elif deflate_result != Z_OK:
                log_zlib_result(deflate_result, compressing=True)

        return result

    fn __del__(owned self):
        if self._initialized:
            _ = self._deflateEnd(UnsafePointer(to=self._stream))
