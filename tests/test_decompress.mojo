"""Tests for the zlib decompress function.

This module tests the decompress function against Python's zlib.decompress
to ensure compatibility and correctness.
"""

import testing
import zlib
from zlib._src.utils_testing import (
    assert_lists_are_equal,
    compress_string_with_python,
    compress_binary_data_with_python,
)


fn test_decompress_empty_data() raises:
    # Generate compressed empty data dynamically
    var compressed = compress_string_with_python("", wbits=15)
    var result = zlib.decompress(compressed)
    testing.assert_equal(len(result), 0)


fn test_decompress_hello_world_zlib() raises:
    var test_string = "Hello, World!"
    var compressed = compress_string_with_python(test_string, wbits=15)
    var expected = test_string.as_bytes()

    var result = zlib.decompress(compressed)
    assert_lists_are_equal(
        result, expected, "Hello World decompression should match expected"
    )


fn test_decompress_hello_world_gzip() raises:
    """Test decompressing "Hello, World!" with gzip format."""
    var test_string = "Hello, World!"
    var compressed = compress_string_with_python(test_string, wbits=31)
    var expected = test_string.as_bytes()

    var result = zlib.decompress(compressed, wbits=31)
    testing.assert_equal(len(result), len(expected))

    assert_lists_are_equal(
        result, expected, "Hello World gzip decompression should match expected"
    )


fn test_decompress_short_string() raises:
    var test_string = "Hi"
    var compressed = compress_string_with_python(test_string, wbits=15)
    var expected = test_string.as_bytes()

    var result = zlib.decompress(compressed)
    testing.assert_equal(len(result), len(expected))

    assert_lists_are_equal(
        result, expected, "Short string decompression should match expected"
    )


fn test_decompress_repeated_pattern() raises:
    """Test decompressing repeated pattern (100 'A's)."""
    var test_string = "A" * 100
    var compressed = compress_string_with_python(test_string, wbits=15)
    var expected = test_string.as_bytes()

    var result = zlib.decompress(compressed)

    assert_lists_are_equal(
        result, expected, "Repeated pattern decompression should match expected"
    )


fn test_decompress_numbers_pattern() raises:
    """Test decompressing repeated number pattern."""
    var test_string = "1234567890" * 10
    var compressed = compress_string_with_python(test_string, wbits=15)
    var expected = test_string.as_bytes()

    var result = zlib.decompress(compressed)

    assert_lists_are_equal(
        result, expected, "Numbers pattern decompression should match expected"
    )


fn test_decompress_binary_data() raises:
    """Test decompressing binary data (all bytes 0-255)."""
    # Generate binary data (0x00 to 0xFF) - doesn't compress well
    var binary_data = [UInt8(i) for i in range(256)]
    var compressed = compress_binary_data_with_python(binary_data, wbits=15)

    var result = zlib.decompress(compressed)

    assert_lists_are_equal(
        result, binary_data, "Binary data decompression should match expected"
    )


fn test_decompress_different_wbits_values() raises:
    """Test decompress with different wbits values."""
    var test_string = "Hello, World!"
    var expected = test_string.as_bytes()

    # Test with default MAX_WBITS (15) - zlib format
    var zlib_compressed = compress_string_with_python(test_string, wbits=15)
    var result_zlib = zlib.decompress(
        zlib_compressed
    )  # Default wbits=MAX_WBITS
    assert_lists_are_equal(
        result_zlib, expected, "zlib decompression should match expected"
    )

    # Test with gzip format (wbits=31)
    var gzip_compressed = compress_string_with_python(test_string, wbits=31)
    var result_gzip = zlib.decompress(gzip_compressed, wbits=31)
    assert_lists_are_equal(
        result_gzip, expected, "gzip decompression should match expected"
    )


fn test_decompress_different_buffer_sizes() raises:
    """Test decompress with different buffer sizes."""
    var test_string = "Hello, World!"
    var compressed = compress_string_with_python(test_string, wbits=15)
    var expected = test_string.as_bytes()

    for bufsize in [1, 16, 65536, zlib.DEF_BUF_SIZE]:
        var result = zlib.decompress(compressed, bufsize=bufsize)
        assert_lists_are_equal(
            result,
            expected,
            "Decompression with bufsize "
            + String(bufsize)
            + " should match expected",
        )


fn test_decompress_positional_only_parameter() raises:
    """Test that the data parameter is positional-only (using /)."""
    var test_string = "Hello, World!"
    var compressed = compress_string_with_python(test_string, wbits=15)

    # These should work - data as positional parameter
    var result1 = zlib.decompress(compressed)
    var result2 = zlib.decompress(compressed, wbits=zlib.MAX_WBITS)
    var result3 = zlib.decompress(
        compressed, wbits=zlib.MAX_WBITS, bufsize=zlib.DEF_BUF_SIZE
    )

    assert_lists_are_equal(
        result1,
        test_string.as_bytes(),
        "Decompression without options should match expected",
    )
    assert_lists_are_equal(
        result2,
        test_string.as_bytes(),
        "Decompression with wbits should match expected",
    )
    assert_lists_are_equal(
        result3,
        test_string.as_bytes(),
        "Decompression with wbits and bufsize should match expected",
    )


fn test_decompress_large_data() raises:
    """Test decompressing larger data set."""
    # Large repeated text compressed with zlib (should compress very well)
    var test_string = "The quick brown fox jumps over the lazy dog. " * 2000
    var compressed = compress_string_with_python(test_string, wbits=15)
    var expected = test_string.as_bytes()

    var result = zlib.decompress(compressed)

    assert_lists_are_equal(
        result, expected, "Large data decompression should match expected"
    )


fn test_decompress_edge_cases() raises:
    """Test edge cases and potential error conditions."""
    # Test with empty compressed data (should fail, but let's see how it handles it)
    with testing.assert_raises(contains="Cannot decompress empty data"):
        _ = zlib.decompress(List[UInt8]())


fn test_decompress_constants_values() raises:
    """Test that constants are properly defined and accessible."""
    # Test that MAX_WBITS is accessible and has the expected value
    testing.assert_equal(zlib.MAX_WBITS, 15)

    # Test that DEF_BUF_SIZE is accessible and has the expected value
    testing.assert_equal(zlib.DEF_BUF_SIZE, 16384)
