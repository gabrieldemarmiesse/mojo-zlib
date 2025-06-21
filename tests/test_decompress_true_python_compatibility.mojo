"""Test zipfile.zlib.decompress compatibility with Python's zlib.decompress.

This module directly compares outputs between Mojo and Python implementations
by calling Python's zlib.decompress in the same process.
"""

import zlib
from testing import assert_equal, assert_true
from python import Python
from zlib._src.utils_testing import (
    to_py_bytes,
    to_mojo_bytes,
    assert_lists_are_equal,
    test_mojo_vs_python_decompress,
)
from random import seed, random_ui64


def test_decompress_empty_data_python_compatibility():
    """Test that our decompress implementation matches Python's results for empty data.
    """
    # Import Python's zlib
    py_zlib = Python.import_module("zlib")

    # First compress empty data with Python to get valid compressed data
    empty_data = List[UInt8]()
    py_empty_bytes = to_py_bytes(empty_data)
    py_compressed = py_zlib.compress(py_empty_bytes)

    # Convert Python compressed result to Mojo bytes and decompress
    mojo_compressed = to_mojo_bytes(py_compressed)
    mojo_result = zlib.decompress(mojo_compressed)

    # Decompress with Python and convert to Mojo
    py_result = py_zlib.decompress(py_compressed)
    py_result_mojo = to_mojo_bytes(py_result)

    # Compare results using utility function
    assert_lists_are_equal(
        mojo_result,
        py_result_mojo,
        "decompressed empty data should match Python",
    )


def test_decompress_hello_python_compatibility():
    """Test that our decompress implementation matches Python's results for 'hello'.
    """
    py_zlib = Python.import_module("zlib")

    # Test simple string "hello"
    hello_data = "hello".as_bytes()
    py_hello_bytes = to_py_bytes(hello_data)
    py_compressed = py_zlib.compress(py_hello_bytes)

    # Convert Python compressed result to Mojo bytes and decompress
    mojo_compressed = to_mojo_bytes(py_compressed)
    mojo_result = zlib.decompress(mojo_compressed)

    # Decompress with Python and convert to Mojo
    py_result = py_zlib.decompress(py_compressed)
    py_result_mojo = to_mojo_bytes(py_result)

    # Compare results using utility function
    assert_lists_are_equal(
        mojo_result, py_result_mojo, "decompressed 'hello' should match Python"
    )


def test_decompress_with_different_wbits_python_compatibility():
    """Test that our decompress implementation matches Python's with different wbits values.
    """
    test_data = "Test data for wbits compatibility testing.".as_bytes()
    wbits_values = [15, -15, 9, -9]  # zlib format, raw deflate format

    for wbits in wbits_values:
        test_mojo_vs_python_decompress(
            test_data,
            wbits=wbits,
            message="decompressed data should match Python for wbits "
            + String(wbits),
        )


def test_decompress_with_different_bufsize_python_compatibility():
    """Test that our decompress implementation matches Python's with different bufsize values.
    """
    test_data = (
        "Test data for bufsize compatibility testing with longer text."
        .as_bytes()
    )
    bufsize_values = [1, 16, 1024, 16384]  # Different buffer sizes

    for bufsize in bufsize_values:
        test_mojo_vs_python_decompress(
            test_data,
            bufsize=bufsize,
            message="decompressed data should match Python for bufsize "
            + String(bufsize),
        )


def test_decompress_large_data_python_compatibility():
    """Test that our decompress implementation matches Python's with large data.
    """
    # Large repetitive data that should compress well
    large_data = (
        "This is a large test string that will be repeated many times. " * 100
    ).as_bytes()

    test_mojo_vs_python_decompress(
        large_data,
        message="decompressed large data should match Python",
    )


def test_decompress_random_data_python_compatibility():
    """Test that our decompress implementation matches Python's with random data.
    """
    # Set seed for reproducible random data
    seed(42)

    # Generate random test data
    var random_data = [UInt8(random_ui64(0, 255)) for _ in range(200)]

    test_mojo_vs_python_decompress(
        random_data,
        message="decompressed random data should match Python",
    )


def test_decompress_binary_data_python_compatibility():
    """Test that our decompress implementation matches Python's with binary data.
    """
    # Binary data with all byte values 0-255
    var binary_data = [UInt8(i) for i in range(256)]

    test_mojo_vs_python_decompress(
        binary_data,
        message="decompressed binary data should match Python",
    )


def test_decompress_mojo_compress_python_decompress_roundtrip():
    """Test that data compressed with Mojo can be decompressed with Python and vice versa.
    """
    py_zlib = Python.import_module("zlib")

    test_data = (
        "Cross-compatibility test between Mojo and Python zlib.".as_bytes()
    )

    # Test 1: Mojo compress -> Python decompress
    mojo_compressed = zlib.compress(test_data)
    py_compressed_bytes = to_py_bytes(mojo_compressed)
    py_decompressed = py_zlib.decompress(py_compressed_bytes)
    py_result_list = to_mojo_bytes(py_decompressed)

    assert_lists_are_equal(
        test_data,
        py_result_list,
        "Mojo compress -> Python decompress should preserve data",
    )

    # Test 2: Python compress -> Mojo decompress
    py_data_bytes = to_py_bytes(test_data)
    py_compressed = py_zlib.compress(py_data_bytes)
    mojo_compressed_from_py = to_mojo_bytes(py_compressed)
    mojo_decompressed = zlib.decompress(mojo_compressed_from_py)

    assert_lists_are_equal(
        test_data,
        mojo_decompressed,
        "Python compress -> Mojo decompress should preserve data",
    )


def test_decompress_compression_levels_python_compatibility():
    """Test that decompress works with data compressed at different levels by Python.
    """
    py_zlib = Python.import_module("zlib")

    test_data = ("Compression level test data. " * 20).as_bytes()
    compression_levels = [
        0,
        1,
        6,
        9,
        -1,
    ]  # No compression, fast, default, best, default (-1)

    for level in compression_levels:
        # Compress with Python at specific level
        py_data_bytes = to_py_bytes(test_data)
        py_compressed = py_zlib.compress(py_data_bytes, level)
        mojo_compressed = to_mojo_bytes(py_compressed)

        # Decompress with both implementations and compare
        mojo_result = zlib.decompress(mojo_compressed)
        py_result = py_zlib.decompress(py_compressed)
        py_result_list = to_mojo_bytes(py_result)

        assert_lists_are_equal(
            mojo_result,
            py_result_list,
            "decompressed data should match Python for level " + String(level),
        )
