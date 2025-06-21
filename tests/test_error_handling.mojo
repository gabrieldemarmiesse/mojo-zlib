"""Test error handling and edge cases for zlib module."""

import zlib
from testing import assert_equal, assert_true, assert_raises


def test_decompress_invalid_data():
    """Test decompression with invalid data."""
    # Test with completely invalid data
    var invalid_data = List[UInt8]()
    invalid_data.append(1)
    invalid_data.append(2)
    invalid_data.append(3)
    invalid_data.append(4)
    invalid_data.append(5)

    with assert_raises():
        _ = zlib.decompress(invalid_data)


def test_decompress_corrupted_data():
    """Test decompression with corrupted data."""
    test_data = "Hello, World!".as_bytes()
    var compressed = zlib.compress(test_data)

    # Create truly corrupt data by changing bytes
    var corrupted = List[UInt8]()
    for i in range(len(compressed)):
        if i < 5:
            corrupted.append(255)  # Replace first 5 bytes with 0xFF
        else:
            corrupted.append(compressed[i])

    with assert_raises():
        _ = zlib.decompress(corrupted)


def test_compress_empty_data():
    """Test compression with empty data."""
    var empty_data = List[UInt8]()

    try:
        var compressed = zlib.compress(empty_data)
        var decompressed = zlib.decompress(compressed)
        assert_equal(
            len(decompressed),
            0,
            "Empty data should compress and decompress to empty",
        )
    except e:
        print("Unexpected error with empty data:", e)
        raise e


def test_decompress_empty_data():
    """Test decompression with empty data."""
    var empty_data = List[UInt8]()

    with assert_raises():
        _ = zlib.decompress(empty_data)


def test_very_large_data():
    """Test with very large data to check memory handling."""
    # Create large repetitive data (should compress well)
    var large_data = List[UInt8]()
    for _ in range(100000):  # 100KB of 'A's
        large_data.append(65)  # 'A'

    try:
        var compressed = zlib.compress(large_data)
        var decompressed = zlib.decompress(compressed)

        assert_equal(
            len(decompressed),
            len(large_data),
            "Large data should roundtrip correctly",
        )

        # Check first and last bytes
        assert_equal(decompressed[0], large_data[0], "First byte should match")
        assert_equal(
            decompressed[len(decompressed) - 1],
            large_data[len(large_data) - 1],
            "Last byte should match",
        )

    except e:
        print("Error with large data:", e)
        raise e


def test_streaming_after_flush():
    """Test that streaming objects cannot be used after flush."""
    test_data = "Test data".as_bytes()

    # Test compressor
    var compressor = zlib.compressobj()
    _ = compressor.compress(test_data)
    _ = compressor.flush()

    # Trying to compress more after flush should error
    with assert_raises():
        _ = compressor.compress(test_data)


def test_streaming_multiple_flush():
    """Test calling flush multiple times on streaming objects."""
    var compressor = zlib.compressobj()

    # First flush
    var flush1 = compressor.flush()

    # Second flush should return empty data
    var flush2 = compressor.flush()
    assert_equal(len(flush2), 0, "Second flush should return empty data")


def test_wbits_format_mismatch():
    """Test decompressing with wrong wbits format."""
    test_data = "Test data for format mismatch".as_bytes()

    # Compress with zlib format (positive wbits)
    var compressed_zlib = zlib.compress(test_data, wbits=15)

    # Try to decompress as raw deflate (negative wbits) - should error
    with assert_raises():
        _ = zlib.decompress(compressed_zlib, wbits=-15)

    # Compress with raw deflate format (negative wbits)
    var compressed_raw = zlib.compress(test_data, wbits=-15)

    # Try to decompress as zlib format (positive wbits) - should error
    with assert_raises():
        _ = zlib.decompress(compressed_raw, wbits=15)


def test_checksum_functions_edge_cases():
    """Test checksum functions with edge cases."""
    # Test with empty data
    var empty_data = List[UInt8]()

    var crc_empty = zlib.crc32(empty_data)
    assert_equal(crc_empty, 0, "CRC32 of empty data should be 0")

    var adler_empty = zlib.adler32(empty_data)
    assert_equal(adler_empty, 1, "Adler32 of empty data should be 1")

    # Test with single byte
    var single_byte = List[UInt8]()
    single_byte.append(65)  # 'A'

    var crc_single = zlib.crc32(single_byte)
    var adler_single = zlib.adler32(single_byte)

    # These should be non-zero for non-empty data
    assert_true(crc_single != 0, "CRC32 of non-empty data should not be 0")
    assert_true(adler_single != 1, "Adler32 of non-empty data should not be 1")


def test_streaming_decompressor_max_length_edge_cases():
    """Test max_length parameter edge cases."""
    test_data = "Test data for max_length edge cases".as_bytes()
    var compressed = zlib.compress(test_data)

    var decompressor = zlib.decompressobj()

    # Test with max_length = 0
    var result_zero = decompressor.decompress(compressed, max_length=0)
    assert_equal(len(result_zero), 0, "max_length=0 should return empty result")

    # Test with max_length = 1
    var result_one = decompressor.decompress(List[UInt8](), max_length=1)
    assert_true(
        len(result_one) <= 1, "max_length=1 should return at most 1 byte"
    )


def main():
    """Run all error handling tests."""
    test_decompress_invalid_data()
    test_decompress_corrupted_data()
    test_compress_empty_data()
    test_decompress_empty_data()
    test_very_large_data()
    test_streaming_after_flush()
    test_streaming_multiple_flush()
    test_wbits_format_mismatch()
    test_checksum_functions_edge_cases()
    test_streaming_decompressor_max_length_edge_cases()
