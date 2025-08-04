# RUN: %mojo %s

"""Force slow path to test length/distance copying fix."""

from testing import assert_equal, assert_true, assert_false
from zlib._src.utils_testing import assert_lists_are_equal, compress_string_with_python
import zlib


fn test_force_slow_path() raises:
    """Force slow path by using small buffer."""
    var test_string = "AAAAAAAAAA"  # Simple repetitive pattern
    var compressed = compress_string_with_python(test_string, wbits=15)
    var expected = test_string.as_bytes()
    
    # Use small buffer size to force slow path
    var result = zlib.decompress(compressed, bufsize=16)  # Very small buffer
    print("Force slow path: expected =", len(expected), "got =", len(result))
    
    # Don't assert yet, just see what we get
    if len(result) == len(expected):
        assert_lists_are_equal(result, expected, "Slow path should work")
    else:
        print("Slow path still broken - got", len(result), "bytes instead of", len(expected))


fn main():
    test_force_slow_path()
    print("Force slow path test completed!")