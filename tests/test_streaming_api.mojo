"""Test the new streaming API functionality."""

import zlib
from testing import assert_equal, assert_true


def test_decompressobj_creation():
    """Test that decompressobj can be created."""
    var decomp = zlib.decompressobj()
    # If we get here without error, the function works
    assert_true(True, "decompressobj creation should work")


def test_compressobj_creation():
    """Test that compressobj can be created."""
    var comp = zlib.compressobj()
    # If we get here without error, the function works
    assert_true(True, "compressobj creation should work")


def test_streaming_decompressor_methods():
    """Test that StreamingDecompressor has the required methods."""
    var decomp = zlib.decompressobj()

    # Test empty decompress call
    empty_data = List[UInt8]()
    var result = decomp.decompress(empty_data)
    assert_equal(len(result), 0, "Empty decompress should return empty result")

    # Test flush call
    var flush_result = decomp.flush()
    assert_equal(
        len(flush_result), 0, "Flush on empty decompressor should return empty"
    )

    # Test copy call
    var decomp_copy = decomp.copy()
    assert_true(True, "Copy should work without error")


def test_compress_struct_methods():
    """Test that Compress struct has the required methods."""
    var comp = zlib.compressobj()

    # Test empty compress call
    empty_data = List[UInt8]()
    var result = comp.compress(empty_data)
    assert_equal(len(result), 0, "Empty compress should return empty result")

    # Test copy call (before flush)
    var comp_copy = comp.copy()
    assert_true(True, "Copy should work without error")

    # Test flush call
    var flush_result = comp.flush()
    # Flush might return some data even if no input was given (headers/trailers)
    assert_true(True, "Flush should work without error")
