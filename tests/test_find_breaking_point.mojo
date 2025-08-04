# RUN: %mojo %s

"""Find the exact breaking point for repetitive sequences."""

from testing import assert_equal, assert_true, assert_false
from zlib._src.utils_testing import assert_lists_are_equal, compress_string_with_python
import zlib


fn test_find_breaking_point() raises:
    """Find where repetitive sequences start to break."""
    print("=== Finding Breaking Point ===")
    
    for length in range(2, 16):  # Test A repeated 2-15 times
        var test_string = ""
        for i in range(length):
            test_string += "A"
        
        var compressed = compress_string_with_python(test_string, wbits=15)
        var expected = test_string.as_bytes()
        var result = zlib.decompress(compressed)
        
        print("Length", length, ": expected =", len(expected), "got =", len(result), end="")
        
        if len(result) == len(expected):
            print(" ✅")
        else:
            print(" ❌ BREAK FOUND!")
            print("First failure at length", length)
            return
    
    print("All lengths up to 15 work!")


fn main():
    test_find_breaking_point()
    print("Breaking point analysis completed!")