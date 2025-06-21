"""Comprehensive tests for streaming compression/decompression API."""

import zlib
from zlib._src.utils_testing import (
    to_py_bytes,
    to_mojo_bytes,
    assert_lists_are_equal,
)
from testing import assert_equal, assert_true
from python import Python


def test_streaming_compress_decompress_roundtrip():
    """Test full roundtrip with streaming compression and decompression."""
    test_data = (
        "Hello, World! This is a test of streaming compression and"
        " decompression.".as_bytes()
    )

    # Compress with streaming API
    var compressor = zlib.compressobj()
    var compressed_chunk1 = compressor.compress(test_data[:20])
    var compressed_chunk2 = compressor.compress(test_data[20:])
    var compressed_final = compressor.flush()

    var full_compressed = (
        compressed_chunk1 + compressed_chunk2 + compressed_final
    )

    # Decompress with streaming API
    var decompressor = zlib.decompressobj()
    var decompressed_chunk1 = decompressor.decompress(full_compressed[:30])
    var decompressed_chunk2 = decompressor.decompress(full_compressed[30:])
    var decompressed_final = decompressor.flush()

    var full_decompressed = (
        decompressed_chunk1 + decompressed_chunk2 + decompressed_final
    )

    assert_lists_are_equal(
        test_data, full_decompressed, "Streaming roundtrip should preserve data"
    )


def test_streaming_vs_single_shot_compression():
    """Test that streaming compression produces same result as single-shot."""
    test_data = "The quick brown fox jumps over the lazy dog. " * 20
    test_bytes = test_data.as_bytes()

    # Single-shot compression
    var single_shot = zlib.compress(test_bytes)

    # Streaming compression
    var compressor = zlib.compressobj()
    var streaming_result = compressor.compress(test_bytes) + compressor.flush()

    assert_lists_are_equal(
        single_shot,
        streaming_result,
        "Streaming and single-shot compression should match",
    )


def test_streaming_vs_single_shot_decompression():
    """Test that streaming decompression produces same result as single-shot."""
    test_data = "The quick brown fox jumps over the lazy dog. " * 20
    test_bytes = test_data.as_bytes()

    # Compress first
    var compressed = zlib.compress(test_bytes)

    # Single-shot decompression
    var single_shot = zlib.decompress(compressed)

    # Streaming decompression
    var decompressor = zlib.decompressobj()
    var streaming_result = (
        decompressor.decompress(compressed) + decompressor.flush()
    )

    assert_lists_are_equal(
        single_shot,
        streaming_result,
        "Streaming and single-shot decompression should match",
    )


def test_streaming_with_different_wbits():
    """Test streaming API with different wbits values."""
    test_data = "Test data for different wbits values.".as_bytes()

    # Test with raw deflate (negative wbits)
    var compressor_raw = zlib.compressobj(wbits=-15)
    var compressed_raw = (
        compressor_raw.compress(test_data) + compressor_raw.flush()
    )

    var decompressor_raw = zlib.decompressobj(wbits=-15)
    var decompressed_raw = (
        decompressor_raw.decompress(compressed_raw) + decompressor_raw.flush()
    )

    assert_lists_are_equal(
        test_data, decompressed_raw, "Raw deflate streaming should work"
    )

    # Test with zlib format (positive wbits)
    var compressor_zlib = zlib.compressobj(wbits=15)
    var compressed_zlib = (
        compressor_zlib.compress(test_data) + compressor_zlib.flush()
    )

    var decompressor_zlib = zlib.decompressobj(wbits=15)
    var decompressed_zlib = (
        decompressor_zlib.decompress(compressed_zlib)
        + decompressor_zlib.flush()
    )

    assert_lists_are_equal(
        test_data, decompressed_zlib, "Zlib format streaming should work"
    )


def test_streaming_copy_functionality():
    """Test the copy functionality of streaming objects."""
    test_data = "Test data for copy functionality.".as_bytes()

    # Test compressor copy
    var original_compressor = zlib.compressobj(level=6)
    var copied_compressor = original_compressor.copy()

    # Both should produce valid compressed data
    var result1 = (
        original_compressor.compress(test_data) + original_compressor.flush()
    )
    var result2 = (
        copied_compressor.compress(test_data) + copied_compressor.flush()
    )

    # Test that both can be decompressed to the original data
    var decompressed1 = zlib.decompress(result1)
    var decompressed2 = zlib.decompress(result2)

    assert_lists_are_equal(
        test_data, decompressed1, "Original compressor should work"
    )
    assert_lists_are_equal(
        test_data, decompressed2, "Copied compressor should work"
    )

    # Test decompressor copy
    var compressed_data = zlib.compress(test_data)
    var original_decompressor = zlib.decompressobj()
    var copied_decompressor = original_decompressor.copy()

    var decompressed_orig = (
        original_decompressor.decompress(compressed_data)
        + original_decompressor.flush()
    )
    var decompressed_copy = (
        copied_decompressor.decompress(compressed_data)
        + copied_decompressor.flush()
    )

    assert_lists_are_equal(
        test_data, decompressed_orig, "Original decompressor should work"
    )
    assert_lists_are_equal(
        test_data, decompressed_copy, "Copied decompressor should work"
    )


def test_streaming_max_length_parameter():
    """Test the max_length parameter in streaming decompression."""
    test_data = "A" * 1000  # Large repetitive data
    test_bytes = test_data.as_bytes()

    var compressed = zlib.compress(test_bytes)
    var decompressor = zlib.decompressobj()

    # Decompress with limited output
    var partial_result = decompressor.decompress(compressed, max_length=100)

    # Should get at most 100 bytes
    assert_true(len(partial_result) <= 100, "max_length should limit output")

    # Get the rest
    var remaining_result = (
        decompressor.decompress(List[UInt8]()) + decompressor.flush()
    )

    var full_result = partial_result + remaining_result
    assert_lists_are_equal(
        test_bytes,
        full_result,
        "Combined partial results should match original",
    )


def main():
    """Run all comprehensive streaming tests."""
    test_streaming_compress_decompress_roundtrip()
    test_streaming_vs_single_shot_compression()
    test_streaming_vs_single_shot_decompression()
    test_streaming_with_different_wbits()
    test_streaming_copy_functionality()
    test_streaming_max_length_parameter()
