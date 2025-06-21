"""Tests to verify that Mojo's decompress function produces identical results to Python's zlib.decompress.

This module directly compares outputs between Mojo and Python implementations.
"""

import testing
import zlib
from zlib._src.utils_testing import assert_lists_are_equal


fn test_decompress_compress_roundtrip() raises:
    """Test that compress -> decompress produces original data."""
    var original_text = "The quick brown fox jumps over the lazy dog!"
    var original_bytes = original_text.as_bytes()

    # Compress with our compress function
    var compressed = zlib.compress(original_bytes)

    # Decompress with our decompress function
    var decompressed = zlib.decompress(compressed)

    # Should get back original data
    testing.assert_equal(len(decompressed), len(original_bytes))
    for i in range(len(original_bytes)):
        testing.assert_equal(decompressed[i], original_bytes[i])


fn test_decompress_different_compression_levels() raises:
    """Test that decompress works with data compressed at different levels."""
    var test_data = "Hello, World! This is a test string for compression."
    var test_bytes = test_data.as_bytes()

    # Test with different compression levels (using compress function)
    # Level 1 (fast)
    var compressed_fast = zlib.compress(test_bytes, level=1)
    var decompressed_fast = zlib.decompress(compressed_fast)
    testing.assert_equal(len(decompressed_fast), len(test_bytes))

    # Level 9 (best compression)
    var compressed_best = zlib.compress(test_bytes, level=9)
    var decompressed_best = zlib.decompress(compressed_best)
    testing.assert_equal(len(decompressed_best), len(test_bytes))

    # Both should produce same result
    for i in range(len(test_bytes)):
        testing.assert_equal(decompressed_fast[i], test_bytes[i])
        testing.assert_equal(decompressed_best[i], test_bytes[i])
        testing.assert_equal(decompressed_fast[i], decompressed_best[i])


fn test_decompress_large_data_roundtrip() raises:
    """Test compress/decompress with larger data."""
    # Create larger test data
    var large_data = List[UInt8]()
    var base_text = "This is a test string for large data compression. "

    # Repeat the text 100 times
    var base_bytes = base_text.as_bytes()
    for _ in range(10000):
        large_data.extend(base_bytes)

    # Compress and decompress
    var compressed = zlib.compress(large_data)
    var decompressed = zlib.decompress(compressed)

    # Verify
    assert_lists_are_equal(
        decompressed,
        large_data,
        "Decompressed data should match original large data",
    )


fn test_decompress_wbits_compatibility() raises:
    """Test that wbits parameter works correctly with different formats."""
    var test_data = "Test data for wbits compatibility."
    var test_bytes = test_data.as_bytes()

    # Test with default wbits (zlib format)
    var compressed_zlib = zlib.compress(test_bytes)  # Default wbits=MAX_WBITS
    var decompressed_zlib = zlib.decompress(
        compressed_zlib
    )  # Default wbits=MAX_WBITS

    testing.assert_equal(len(decompressed_zlib), len(test_bytes))
    for i in range(len(test_bytes)):
        testing.assert_equal(decompressed_zlib[i], test_bytes[i])

    # Test with raw deflate format
    var compressed_raw = zlib.compress(test_bytes, wbits=-zlib.MAX_WBITS)
    var decompressed_raw = zlib.decompress(
        compressed_raw, wbits=-zlib.MAX_WBITS
    )

    assert_lists_are_equal(
        decompressed_raw,
        test_bytes,
        "Decompressed raw data should match original",
    )


fn test_decompress_various_data_types() raises:
    """Test decompress with various data patterns."""
    # Test with repeated patterns
    var repeated = [UInt8(65) for _ in range(1000)]

    var compressed_repeated = zlib.compress(repeated)
    var decompressed_repeated = zlib.decompress(compressed_repeated)
    assert_lists_are_equal(
        decompressed_repeated,
        repeated,
        "Decompressed repeated pattern should match original",
    )

    # Test with random-like pattern
    var random_like = [UInt8(i) for i in range(256)]

    var compressed_random = zlib.compress(random_like)
    var decompressed_random = zlib.decompress(compressed_random)
    assert_lists_are_equal(
        decompressed_random,
        random_like,
        "Decompressed random-like data should match original",
    )


fn test_decompress_empty_data_roundtrip() raises:
    """Test compress/decompress roundtrip with empty data."""
    var empty_data = List[UInt8]()

    var compressed = zlib.compress(empty_data)
    var decompressed = zlib.decompress(compressed)

    testing.assert_equal(len(decompressed), 0)
