"""Test all zlib constants and their compatibility with Python."""

import zlib
from testing import assert_equal, assert_true


def test_compression_level_constants():
    """Test compression level constants."""
    # Test that constants exist and have correct values
    assert_equal(Int(zlib.Z_NO_COMPRESSION), 0, "Z_NO_COMPRESSION should be 0")
    assert_equal(Int(zlib.Z_BEST_SPEED), 1, "Z_BEST_SPEED should be 1")
    assert_equal(
        Int(zlib.Z_DEFAULT_COMPRESSION),
        -1,
        "Z_DEFAULT_COMPRESSION should be -1",
    )
    assert_equal(
        Int(zlib.Z_BEST_COMPRESSION), 9, "Z_BEST_COMPRESSION should be 9"
    )


def test_compression_method_constants():
    """Test compression method constants."""
    assert_equal(Int(zlib.DEFLATED), 8, "DEFLATED should be 8")


def test_flush_mode_constants():
    """Test flush mode constants."""
    assert_equal(Int(zlib.Z_NO_FLUSH), 0, "Z_NO_FLUSH should be 0")
    assert_equal(Int(zlib.Z_PARTIAL_FLUSH), 1, "Z_PARTIAL_FLUSH should be 1")
    assert_equal(Int(zlib.Z_SYNC_FLUSH), 2, "Z_SYNC_FLUSH should be 2")
    assert_equal(Int(zlib.Z_FULL_FLUSH), 3, "Z_FULL_FLUSH should be 3")
    assert_equal(Int(zlib.Z_FINISH), 4, "Z_FINISH should be 4")
    assert_equal(Int(zlib.Z_BLOCK), 5, "Z_BLOCK should be 5")
    assert_equal(Int(zlib.Z_TREES), 6, "Z_TREES should be 6")


def test_compression_strategy_constants():
    """Test compression strategy constants."""
    assert_equal(
        Int(zlib.Z_DEFAULT_STRATEGY), 0, "Z_DEFAULT_STRATEGY should be 0"
    )
    assert_equal(Int(zlib.Z_FILTERED), 1, "Z_FILTERED should be 1")
    assert_equal(Int(zlib.Z_HUFFMAN_ONLY), 2, "Z_HUFFMAN_ONLY should be 2")
    assert_equal(Int(zlib.Z_RLE), 3, "Z_RLE should be 3")
    assert_equal(Int(zlib.Z_FIXED), 4, "Z_FIXED should be 4")


def test_buffer_and_window_constants():
    """Test buffer size and window constants."""
    assert_equal(zlib.MAX_WBITS, 15, "MAX_WBITS should be 15")
    assert_equal(zlib.DEF_BUF_SIZE, 16384, "DEF_BUF_SIZE should be 16384")
    assert_equal(Int(zlib.DEF_MEM_LEVEL), 8, "DEF_MEM_LEVEL should be 8")


def test_version_constants():
    """Test version constants."""
    # Test that version strings exist and are reasonable
    assert_true(len(zlib.ZLIB_VERSION) > 0, "ZLIB_VERSION should not be empty")
    assert_true(
        len(zlib.ZLIB_RUNTIME_VERSION) > 0,
        "ZLIB_RUNTIME_VERSION should not be empty",
    )
    assert_true(
        "." in zlib.ZLIB_VERSION, "ZLIB_VERSION should contain version format"
    )
    assert_true(
        "." in zlib.ZLIB_RUNTIME_VERSION,
        "ZLIB_RUNTIME_VERSION should contain version format",
    )


def test_constants_used_in_compression():
    """Test that constants can be used in actual compression operations."""
    test_data = "Test data for constant usage.".as_bytes()

    # Test a few compression levels
    var compressed = zlib.compress(test_data, level=Int(zlib.Z_BEST_SPEED))
    var decompressed = zlib.decompress(compressed)
    assert_equal(len(decompressed), len(test_data), "Z_BEST_SPEED should work")

    # Test with different wbits
    var compressed_raw = zlib.compress(test_data, wbits=-zlib.MAX_WBITS)
    var decompressed_raw = zlib.decompress(
        compressed_raw, wbits=-zlib.MAX_WBITS
    )
    assert_equal(
        len(decompressed_raw), len(test_data), "Raw deflate should work"
    )
