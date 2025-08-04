# RUN: %mojo %s

"""Diagnose LZ77 length/distance issues."""

from testing import assert_equal, assert_true, assert_false
from zlib._src.utils_testing import assert_lists_are_equal, compress_string_with_python
import zlib


fn test_literals_only() raises:
    """Test string with no repetition (should work perfectly)."""
    var test_string = "ABCDEFGHIJ"  # All different characters
    var compressed = compress_string_with_python(test_string, wbits=15)
    var expected = test_string.as_bytes()
    var result = zlib.decompress(compressed)
    print("Literals only: expected =", len(expected), "got =", len(result))
    assert_lists_are_equal(result, expected, "Literals should work")


fn test_simple_repeat() raises:
    """Test simple 2-char repeat."""
    var test_string = "AA"  # Minimal repeat
    var compressed = compress_string_with_python(test_string, wbits=15)
    var expected = test_string.as_bytes()
    var result = zlib.decompress(compressed)
    print("Simple repeat: expected =", len(expected), "got =", len(result))
    if len(result) != len(expected):
        print("FAILED: Simple repeat failed")
    else:
        assert_lists_are_equal(result, expected, "Simple repeat should work")


fn test_longer_repeat() raises:
    """Test longer repeat."""
    var test_string = "AAAA"  # 4-char repeat
    var compressed = compress_string_with_python(test_string, wbits=15)
    var expected = test_string.as_bytes()
    var result = zlib.decompress(compressed)
    print("Longer repeat: expected =", len(expected), "got =", len(result))
    if len(result) != len(expected):
        print("FAILED: Longer repeat failed")
    else:
        assert_lists_are_equal(result, expected, "Longer repeat should work")


fn test_mixed_content() raises:
    """Test mixed literals and repeats."""
    var test_string = "ABCABC"  # ABC pattern repeated
    var compressed = compress_string_with_python(test_string, wbits=15)
    var expected = test_string.as_bytes()
    var result = zlib.decompress(compressed)
    print("Mixed content: expected =", len(expected), "got =", len(result))
    if len(result) != len(expected):
        print("FAILED: Mixed content failed")
    else:
        assert_lists_are_equal(result, expected, "Mixed content should work")


fn main():
    print("=== Diagnosing LZ77 Issues ===")
    test_literals_only()
    test_simple_repeat()
    test_longer_repeat()
    test_mixed_content()
    print("Diagnosis completed!")