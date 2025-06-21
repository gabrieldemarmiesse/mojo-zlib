from sys import ffi

alias Bytef = Scalar[DType.uint8]
alias uLong = UInt64

alias z_stream_ptr = UnsafePointer[ZStream]  # forward-declared below


# Cleaner than declaring an __init__()
@fieldwise_init
struct ZStream(Copyable, Movable):
    var next_in: UnsafePointer[Bytef]
    var avail_in: UInt32
    var total_in: uLong
    var next_out: UnsafePointer[Bytef]
    var avail_out: UInt32
    var total_out: uLong
    var msg: UnsafePointer[UInt8]
    var state: UnsafePointer[UInt8]
    var zalloc: UnsafePointer[UInt8]
    var zfree: UnsafePointer[UInt8]
    var opaque: UnsafePointer[UInt8]
    var data_type: Int32
    var adler: uLong
    var reserved: uLong


alias inflateInit2_type = fn (
    strm: z_stream_ptr,
    windowBits: Int32,
    version: UnsafePointer[UInt8],
    stream_size: Int32,
) -> ffi.c_int
alias inflate_type = fn (strm: z_stream_ptr, flush: ffi.c_int) -> ffi.c_int
alias inflateEnd_type = fn (strm: z_stream_ptr) -> ffi.c_int

alias deflateInit2_type = fn (
    strm: z_stream_ptr,
    level: Int32,
    method: Int32,
    windowBits: Int32,
    memLevel: Int32,
    strategy: Int32,
    version: UnsafePointer[UInt8],
    stream_size: Int32,
) -> ffi.c_int
alias deflate_type = fn (strm: z_stream_ptr, flush: ffi.c_int) -> ffi.c_int
alias deflateEnd_type = fn (strm: z_stream_ptr) -> ffi.c_int

alias adler32_type = fn (
    adler: uLong, buf: UnsafePointer[Bytef], len: UInt32
) -> uLong

alias crc32_type = fn (
    crc: uLong, buf: UnsafePointer[Bytef], len: UInt32
) -> uLong

alias Z_OK: ffi.c_int = 0
alias Z_STREAM_END: ffi.c_int = 1
alias Z_NO_FLUSH: ffi.c_int = 0
alias Z_SYNC_FLUSH: ffi.c_int = 2
alias Z_FINISH: ffi.c_int = 4

# Compression levels
alias Z_DEFAULT_COMPRESSION: Int32 = -1
alias Z_BEST_COMPRESSION: Int32 = 9
alias Z_BEST_SPEED: Int32 = 1
alias Z_NO_COMPRESSION: Int32 = 0

# Compression methods
alias Z_DEFLATED: Int32 = 8
alias DEFLATED: Int32 = 8  # Python alias for Z_DEFLATED

# Compression strategies
alias Z_DEFAULT_STRATEGY: Int32 = 0
alias Z_FILTERED: Int32 = 1
alias Z_HUFFMAN_ONLY: Int32 = 2
alias Z_RLE: Int32 = 3
alias Z_FIXED: Int32 = 4

# Flush modes
alias Z_PARTIAL_FLUSH: Int32 = 1
alias Z_FULL_FLUSH: Int32 = 3
alias Z_BLOCK: Int32 = 5
alias Z_TREES: Int32 = 6

# Window bits
alias MAX_WBITS: Int = 15

# Buffer size
alias DEF_BUF_SIZE: Int = 16384

# Memory level
alias DEF_MEM_LEVEL: Int32 = 8

# Version strings - these would normally be retrieved from zlib at runtime
alias ZLIB_VERSION: String = "1.2.11"
alias ZLIB_RUNTIME_VERSION: String = "1.2.11"


fn log_zlib_result(Z_RES: ffi.c_int, compressing: Bool = True) raises -> None:
    var prefix: String = ""
    if not compressing:
        prefix = "un"

    if Z_RES == Z_OK or Z_RES == Z_STREAM_END:
        pass
    elif Z_RES == -4:
        raise Error(
            "ERROR " + prefix.upper() + "COMPRESSING: Not enough memory"
        )
    elif Z_RES == -5:
        raise Error(
            "ERROR "
            + prefix.upper()
            + "COMPRESSING: Buffer has not enough memory"
        )
    elif Z_RES == -3:
        raise Error(
            "ERROR "
            + prefix.upper()
            + "COMPRESSING: Data error (bad input format or corrupted)"
        )
    else:
        raise Error(
            "ERROR "
            + prefix.upper()
            + "COMPRESSING: Unhandled exception, got code "
            + String(Z_RES)
        )
