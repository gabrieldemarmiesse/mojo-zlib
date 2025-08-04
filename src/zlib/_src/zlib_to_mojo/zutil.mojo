# Core utility functions for native Mojo zlib implementation
# Based on zutil.h and zutil.c from zlib 1.3.1.1

from memory import memcpy, memset_zero, memcmp, UnsafePointer
from sys import ffi

# Additional zlib constants from zutil.h
alias DEF_WBITS = 15  # Default window bits for decompression
alias STORED_BLOCK = 0
alias STATIC_TREES = 1  
alias DYN_TREES = 2
alias MIN_MATCH = 3
alias MAX_MATCH = 258
alias PRESET_DICT = 0x20  # Preset dictionary flag in zlib header

# Common error codes (matching zlib values)
alias Z_NEED_DICT: Int32 = 2
alias Z_STREAM_ERROR: Int32 = -2
alias Z_DATA_ERROR: Int32 = -3
alias Z_MEM_ERROR: Int32 = -4
alias Z_BUF_ERROR: Int32 = -5
alias Z_VERSION_ERROR: Int32 = -6


# Error message table matching zlib z_errmsg
alias Z_ERRMSG = InlineArray[String, 10](
    "need dictionary",      # Z_NEED_DICT       2
    "stream end",           # Z_STREAM_END      1  
    "",                     # Z_OK              0
    "file error",           # Z_ERRNO         (-1)
    "stream error",         # Z_STREAM_ERROR  (-2)
    "data error",           # Z_DATA_ERROR    (-3)
    "insufficient memory",  # Z_MEM_ERROR     (-4)
    "buffer error",         # Z_BUF_ERROR     (-5)
    "incompatible version", # Z_VERSION_ERROR (-6)
    ""
)


fn zmemcpy[O: MutableOrigin](dest: UnsafePointer[UInt8, mut = O.mut, origin=O], src: UnsafePointer[UInt8], len: UInt):
    """Copy len bytes from src to dest.
    
    Args:
        dest: Destination pointer.
        src: Source pointer.
        len: Number of bytes to copy.
    """
    if len == 0:
        return
    memcpy(dest, src, Int(len))


fn zmemset[O: MutableOrigin](ptr: UnsafePointer[UInt8, mut = O.mut, origin=O], value: UInt8, len: UInt):
    """Set len bytes at ptr to value.
    
    Args:
        ptr: Pointer to memory to set.
        value: Value to set bytes to.
        len: Number of bytes to set.
    """
    if len == 0:
        return
    if value == 0:
        memset_zero(ptr, Int(len))
    else:
        # Manual implementation for non-zero values
        for i in range(Int(len)):
            ptr[i] = value


fn zmemcmp(s1: UnsafePointer[UInt8], s2: UnsafePointer[UInt8], len: UInt) -> Int:
    """Compare len bytes at s1 and s2.
    
    Args:
        s1: First memory block.
        s2: Second memory block.
        len: Number of bytes to compare.
        
    Returns:
        0 if equal, <0 if s1 < s2, >0 if s1 > s2.
    """
    if len == 0:
        return 0
    return memcmp[type=UInt8](s1, s2, Int(len))


fn zcalloc(items: UInt, size: UInt) -> UnsafePointer[UInt8]:
    """Allocate and zero-initialize memory.
    
    Args:
        items: Number of items.
        size: Size of each item in bytes.
        
    Returns:
        Pointer to allocated memory, or null pointer if allocation fails.
    """
    total_size = items * size
    if total_size == 0:
        return UnsafePointer[UInt8]()
        
    ptr = UnsafePointer[UInt8].alloc(Int(total_size))
    memset_zero(ptr, Int(total_size))
    return ptr


fn zcfree(ptr: UnsafePointer[UInt8]):
    """Free memory allocated by zcalloc.
    
    Args:
        ptr: Pointer to memory to free.
    """
    if ptr:
        ptr.free()


fn zError(err: Int32) -> String:
    """Convert zlib error code to error message.
    
    Args:
        err: zlib error code.
        
    Returns:
        Error message string.
    """
    # Convert error code to array index: index = 2 - err
    # Z_NEED_DICT (2) -> 0, Z_STREAM_END (1) -> 1, Z_OK (0) -> 2, 
    # Z_ERRNO (-1) -> 3, etc.
    var index = 2 - Int(err)
    if index < 0 or index >= 10:
        index = 9  # Use empty string for unknown errors
    return Z_ERRMSG[index]


# Additional utility functions for bit manipulation commonly used in zlib

fn ZSWAP32(q: UInt32) -> UInt32:
    """Reverse the bytes in a 32-bit value.
    
    Args:
        q: 32-bit value to byte-swap.
        
    Returns:
        Byte-swapped value.
    """
    return ((q >> 24) & 0xFF) | ((q >> 8) & 0xFF00) | ((q & 0xFF00) << 8) | ((q & 0xFF) << 24)