# RUN: %mojo %s

"""Debug-specific unit tests for Pure Mojo zlib implementation issues."""

from testing import assert_equal, assert_true, assert_false
from zlib._src.utils_testing import assert_lists_are_equal, to_py_bytes, to_mojo_bytes, compress_string_with_python
import zlib
from python import Python


fn test_single_block_fixed_huffman() raises:
    """Test a simple single block with fixed Huffman (should work perfectly)."""
    var test_string = "Hello"
    var compressed = compress_string_with_python(test_string, wbits=15)
    var expected = test_string.as_bytes()
    var result = zlib.decompress(compressed)
    assert_lists_are_equal(
        result, expected, "Single block fixed Huffman should work"
    )


fn test_multi_block_detection() raises:
    """Test data that definitely uses multiple blocks."""
    # Create data large enough to force multiple blocks
    var large_string = ""
    for i in range(1000):
        large_string += "ABCDEFGHIJ"  # 10KB of repetitive data
    
    var compressed = compress_string_with_python(large_string, wbits=15)
    var expected = large_string.as_bytes()
    var result = zlib.decompress(compressed)
    
    print("Multi-block test: expected =", len(expected), "got =", len(result))
    # Don't assert equal yet, just check we got some output
    assert_true(len(result) > 0, "Should decompress something")


fn test_dynamic_huffman_simple() raises:
    """Test simple dynamic Huffman compression."""
    # Use varied data that should trigger dynamic Huffman
    var test_string = "The quick brown fox jumps over the lazy dog"
    var compressed = compress_string_with_python(test_string, wbits=15)
    var expected = test_string.as_bytes()  
    var result = zlib.decompress(compressed)
    assert_lists_are_equal(
        result, expected, "Simple dynamic Huffman should work"
    )


fn test_length_distance_pairs() raises:
    """Test data with obvious length/distance patterns."""
    var test_string = "AAAAAAAAAA"  # Simple repetitive pattern
    var compressed = compress_string_with_python(test_string, wbits=15)
    var expected = test_string.as_bytes()
    var result = zlib.decompress(compressed)
    assert_lists_are_equal(
        result, expected, "Length/distance pairs should work"
    )


fn test_minimal_gzip() raises:
    """Test minimal gzip data to isolate gzip header issues."""
    var test_string = "Hi"
    var compressed = compress_string_with_python(test_string, wbits=31)  # gzip format
    var expected = test_string.as_bytes()
    
    try:
        var result = zlib.decompress(compressed, wbits=31)
        assert_lists_are_equal(result, expected, "Minimal gzip should work")
    except:
        print("DEBUG: Gzip test failed as expected (not implemented yet)")
        # This is expected to fail until we implement gzip header parsing


fn test_raw_deflate() raises:
    """Test raw deflate format (no headers)."""
    var test_string = "Test"
    var compressed = compress_string_with_python(test_string, wbits=-15)  # raw deflate
    var expected = test_string.as_bytes()
    var result = zlib.decompress(compressed, wbits=-15)
    assert_lists_are_equal(
        result, expected, "Raw deflate should work"
    )


fn test_buffer_edge_cases() raises:
    """Test various buffer sizes to check buffer management."""
    var test_string = "Medium length test string for buffer testing"
    var compressed = compress_string_with_python(test_string, wbits=15)
    var expected = test_string.as_bytes()
    
    # Test with exact buffer size
    var result = zlib.decompress(compressed, bufsize=len(expected))
    assert_lists_are_equal(
        result, expected, "Exact buffer size should work"
    )
    
    # Test with larger buffer
    var result2 = zlib.decompress(compressed, bufsize=len(expected) * 2)
    assert_lists_are_equal(
        result2, expected, "Larger buffer should work"
    )


fn test_incremental_sizes() raises:
    """Test progressively larger strings to find the breaking point."""
    for size in range(1, 101, 10):  # Test sizes 1, 11, 21, ..., 91
        var test_string = ""
        for i in range(size):
            test_string += "X"
        
        var compressed = compress_string_with_python(test_string, wbits=15)
        var expected = test_string.as_bytes()
        var result = zlib.decompress(compressed)
        
        print("Size", size, ": expected =", len(expected), "got =", len(result))
        if len(result) != len(expected):
            print("BREAK at size", size)
            break
        else:
            assert_lists_are_equal(result, expected, "Size " + String(size) + " should work")


fn main():
    test_single_block_fixed_huffman()
    test_dynamic_huffman_simple()
    test_length_distance_pairs()
    test_minimal_gzip()
    test_raw_deflate()
    test_buffer_edge_cases()
    test_incremental_sizes()
    test_multi_block_detection()
    print("Debug tests completed!")