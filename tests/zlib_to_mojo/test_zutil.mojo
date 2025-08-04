"""Unit tests for zutil.mojo core utilities."""

from memory import UnsafePointer, memset_zero
from testing import assert_equal, assert_not_equal, assert_true, assert_false

from zlib._src.zlib_to_mojo.zutil import (
    zmemcpy, zmemset, zmemcmp, zcalloc, zcfree, zError, ZSWAP32,
    Z_ERRMSG, Z_NEED_DICT, Z_STREAM_ERROR, Z_DATA_ERROR, Z_MEM_ERROR,
    Z_BUF_ERROR, Z_VERSION_ERROR
)


def test_zmemcpy():
    """Test zmemcpy function."""
    # Allocate source and destination buffers
    src = UnsafePointer[UInt8].alloc(10)
    dest = UnsafePointer[UInt8].alloc(10)
    
    # Initialize source with test data
    for i in range(10):
        src[i] = UInt8(i + 1)
    
    # Zero destination
    memset_zero(dest, 10)
    
    # Test copying 5 bytes
    zmemcpy(dest, src, 5)
    
    # Verify the copy
    for i in range(5):
        assert_equal(dest[i], UInt8(i + 1))
    
    # Verify remaining bytes are still zero
    for i in range(5, 10):
        assert_equal(dest[i], UInt8(0))
    
    # Test copying 0 bytes (should do nothing)
    zmemcpy(dest.offset(5), src.offset(5), 0)
    assert_equal(dest[5], UInt8(0))
    
    # Clean up
    src.free()
    dest.free()


def test_zmemset():
    """Test zmemset function."""
    ptr = UnsafePointer[UInt8].alloc(10)
    
    # Test setting to zero
    zmemset(ptr, 0, 10)
    for i in range(10):
        assert_equal(ptr[i], UInt8(0))
    
    # Test setting to non-zero value
    zmemset(ptr, 0xAB, 5)
    for i in range(5):
        assert_equal(ptr[i], UInt8(0xAB))
    for i in range(5, 10):
        assert_equal(ptr[i], UInt8(0))
    
    # Test setting 0 bytes (should do nothing)
    zmemset(ptr, 0xFF, 0)
    assert_equal(ptr[0], UInt8(0xAB))
    
    ptr.free()


def test_zmemcmp():
    """Test zmemcmp function."""
    ptr1 = UnsafePointer[UInt8].alloc(10) 
    ptr2 = UnsafePointer[UInt8].alloc(10)
    
    # Initialize both with same data
    for i in range(10):
        ptr1[i] = UInt8(i)
        ptr2[i] = UInt8(i)
    
    # Test equal memory regions
    assert_equal(zmemcmp(ptr1, ptr2, 10), 0)
    assert_equal(zmemcmp(ptr1, ptr2, 5), 0)
    assert_equal(zmemcmp(ptr1, ptr2, 0), 0)
    
    # Make first byte different
    ptr2[0] = UInt8(1)  # ptr1[0] = 0, ptr2[0] = 1
    assert_true(zmemcmp(ptr1, ptr2, 10) < 0)  # ptr1 < ptr2
    
    ptr2[0] = UInt8(0)
    ptr1[5] = UInt8(10)  # ptr1[5] = 10, ptr2[5] = 5
    assert_true(zmemcmp(ptr1, ptr2, 10) > 0)  # ptr1 > ptr2
    
    ptr1.free()
    ptr2.free()


def test_zcalloc_zcfree():
    """Test zcalloc and zcfree functions."""
    # Test normal allocation
    ptr = zcalloc(10, 4)  # 40 bytes
    assert_not_equal(ptr, UnsafePointer[UInt8]())
    
    # Verify memory is zeroed
    for i in range(40):
        assert_equal(ptr[i], UInt8(0))
    
    # Test that we can write to the memory
    ptr[0] = UInt8(123)
    assert_equal(ptr[0], UInt8(123))
    
    # Free the memory
    zcfree(ptr)
    
    # Test zero allocation
    ptr_zero = zcalloc(0, 10)
    assert_equal(ptr_zero, UnsafePointer[UInt8]())
    
    # Test allocation with size 0
    ptr_zero2 = zcalloc(10, 0)
    assert_equal(ptr_zero2, UnsafePointer[UInt8]())


def test_zError():
    """Test zError function for converting error codes to messages."""
    # Test known error codes
    assert_equal(zError(Int32(2)), "need dictionary")  # Z_NEED_DICT
    assert_equal(zError(Int32(1)), "stream end")       # Z_STREAM_END
    assert_equal(zError(Int32(0)), "")                 # Z_OK
    assert_equal(zError(Int32(-1)), "file error")      # Z_ERRNO
    assert_equal(zError(Int32(-2)), "stream error")    # Z_STREAM_ERROR
    assert_equal(zError(Int32(-3)), "data error")      # Z_DATA_ERROR
    assert_equal(zError(Int32(-4)), "insufficient memory")  # Z_MEM_ERROR
    assert_equal(zError(Int32(-5)), "buffer error")    # Z_BUF_ERROR
    assert_equal(zError(Int32(-6)), "incompatible version")  # Z_VERSION_ERROR
    
    # Test unknown error codes (should return empty string)
    assert_equal(zError(Int32(10)), "")
    assert_equal(zError(Int32(-10)), "")


def test_ZSWAP32():
    """Test ZSWAP32 function for byte swapping."""
    # Test known values
    assert_equal(ZSWAP32(0x12345678), 0x78563412)
    assert_equal(ZSWAP32(0x00000000), 0x00000000)
    assert_equal(ZSWAP32(0xFFFFFFFF), 0xFFFFFFFF)
    assert_equal(ZSWAP32(0x12000000), 0x00000012)
    assert_equal(ZSWAP32(0x00000034), 0x34000000)
    
    # Test that swapping twice gives original value
    var original: UInt32 = 0xABCD1234
    var swapped = ZSWAP32(original)
    var double_swapped = ZSWAP32(swapped)
    assert_equal(double_swapped, original)


def test_constants():
    """Test that constants are properly defined."""
    # Test error code constants
    assert_equal(Z_NEED_DICT, Int32(2))
    assert_equal(Z_STREAM_ERROR, Int32(-2))
    assert_equal(Z_DATA_ERROR, Int32(-3))
    assert_equal(Z_MEM_ERROR, Int32(-4))
    assert_equal(Z_BUF_ERROR, Int32(-5))
    assert_equal(Z_VERSION_ERROR, Int32(-6))
    
    # Test that error message array has correct size
    assert_equal(len(Z_ERRMSG), 10)


def test_error_message_array():
    """Test that error message array matches expected values."""
    assert_equal(Z_ERRMSG[0], "need dictionary")
    assert_equal(Z_ERRMSG[1], "stream end")
    assert_equal(Z_ERRMSG[2], "")
    assert_equal(Z_ERRMSG[3], "file error")
    assert_equal(Z_ERRMSG[4], "stream error")
    assert_equal(Z_ERRMSG[5], "data error")
    assert_equal(Z_ERRMSG[6], "insufficient memory")
    assert_equal(Z_ERRMSG[7], "buffer error")
    assert_equal(Z_ERRMSG[8], "incompatible version")
    assert_equal(Z_ERRMSG[9], "")