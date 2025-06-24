from ._src.checksums import adler32, crc32
from ._src.compression import compress, compressobj, Compress
from ._src.decompression import decompress, decompressobj, Decompress
from ._src.constants import (
    # Python-compatible constants
    DEFLATED,
    DEF_BUF_SIZE,
    DEF_MEM_LEVEL,
    MAX_WBITS,
    ZLIB_RUNTIME_VERSION,
    ZLIB_VERSION,
    # Compression levels
    Z_BEST_COMPRESSION,
    Z_BEST_SPEED,
    Z_DEFAULT_COMPRESSION,
    Z_NO_COMPRESSION,
    # Flush modes
    Z_BLOCK,
    Z_FINISH,
    Z_FULL_FLUSH,
    Z_NO_FLUSH,
    Z_PARTIAL_FLUSH,
    Z_SYNC_FLUSH,
    Z_TREES,
    # Compression strategies
    Z_DEFAULT_STRATEGY,
    Z_FILTERED,
    Z_FIXED,
    Z_HUFFMAN_ONLY,
    Z_RLE,
)
