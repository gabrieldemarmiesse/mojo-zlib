"""Test zipfile.zlib.compress compatibility with Python's zlib.compress."""

import zlib
from testing import assert_equal, assert_true
from python import Python
from zlib._src.utils_testing import to_py_bytes
from random import seed, random_ui64


def test_compress_empty_data_python_compatibility():
    """Test that our compress implementation matches Python's results for empty data.
    """
    # Import Python's zlib
    py_zlib = Python.import_module("zlib")

    # Test empty data
    empty_data = List[UInt8]()
    mojo_result = zlib.compress(empty_data)
    py_empty_bytes = to_py_bytes(empty_data)
    py_result = py_zlib.compress(py_empty_bytes)

    # Convert Python bytes result to list for comparison
    py_result_list = List[UInt8]()
    for i in range(len(py_result)):
        py_result_list.append(UInt8(Int(py_result[i])))

    assert_equal(
        len(mojo_result),
        len(py_result_list),
        "compressed empty data length should match Python",
    )
    for i in range(len(mojo_result)):
        assert_equal(
            mojo_result[i],
            py_result_list[i],
            "compressed empty data bytes should match Python",
        )


def test_compress_hello_python_compatibility():
    """Test that our compress implementation matches Python's results for 'hello'.
    """
    py_zlib = Python.import_module("zlib")

    # Test simple string "hello"
    hello_data = String("hello").as_bytes()
    mojo_result = zlib.compress(hello_data)
    py_hello_bytes = to_py_bytes(hello_data)
    py_result = py_zlib.compress(py_hello_bytes)

    # Convert Python bytes result to list for comparison
    py_result_list = List[UInt8]()
    for i in range(len(py_result)):
        py_result_list.append(UInt8(Int(py_result[i])))

    assert_equal(
        len(mojo_result),
        len(py_result_list),
        "compressed 'hello' length should match Python",
    )
    for i in range(len(mojo_result)):
        assert_equal(
            mojo_result[i],
            py_result_list[i],
            "compressed 'hello' bytes should match Python",
        )


def test_compress_with_compression_levels_python_compatibility():
    """Test that our compress implementation matches Python's results with different compression levels.
    """
    py_zlib = Python.import_module("zlib")

    test_data = String(
        "The quick brown fox jumps over the lazy dog. " * 10
    ).as_bytes()
    compression_levels = [
        0,
        1,
        6,
        9,
        -1,
    ]  # No compression, fast, default, best, default (-1)

    for level in compression_levels:
        mojo_result = zlib.compress(test_data, level=level)
        py_data_bytes = to_py_bytes(test_data)
        py_result = py_zlib.compress(py_data_bytes, level)

        # Convert Python bytes result to list for comparison
        py_result_list = List[UInt8]()
        for i in range(len(py_result)):
            py_result_list.append(UInt8(Int(py_result[i])))

        assert_equal(
            len(mojo_result),
            len(py_result_list),
            "compressed data length should match Python for level "
            + String(level),
        )
        for i in range(len(mojo_result)):
            assert_equal(
                mojo_result[i],
                py_result_list[i],
                "compressed data bytes should match Python for level "
                + String(level),
            )


def test_compress_with_wbits_python_compatibility():
    """Test that our compress implementation matches Python's results with different wbits values.
    """
    py_zlib = Python.import_module("zlib")

    test_data = String(
        "Hello, World! This is a test for wbits parameter."
    ).as_bytes()
    wbits_values = [15, -15, 9, -9]  # zlib format, raw deflate format

    for wbits in wbits_values:
        mojo_result = zlib.compress(test_data, wbits=wbits)
        py_data_bytes = to_py_bytes(test_data)
        py_result = py_zlib.compress(py_data_bytes, wbits=wbits)

        # Convert Python bytes result to list for comparison
        py_result_list = List[UInt8]()
        for i in range(len(py_result)):
            py_result_list.append(UInt8(Int(py_result[i])))

        assert_equal(
            len(mojo_result),
            len(py_result_list),
            "compressed data length should match Python for wbits "
            + String(wbits),
        )
        for i in range(len(mojo_result)):
            assert_equal(
                mojo_result[i],
                py_result_list[i],
                "compressed data bytes should match Python for wbits "
                + String(wbits),
            )


def test_compress_random_data_python_compatibility():
    """Test that our compress implementation matches Python's results with random data.
    """
    py_zlib = Python.import_module("zlib")

    # Set seed for reproducible random data
    seed(42)

    # Generate random test data
    test_data = List[UInt8]()
    for _ in range(100):
        test_data.append(Byte(random_ui64(0, 255)))

    mojo_result = zlib.compress(test_data)
    py_data_bytes = to_py_bytes(test_data)
    py_result = py_zlib.compress(py_data_bytes)

    # Convert Python bytes result to list for comparison
    py_result_list = List[UInt8]()
    for i in range(len(py_result)):
        py_result_list.append(UInt8(Int(py_result[i])))

    assert_equal(
        len(mojo_result),
        len(py_result_list),
        "compressed random data length should match Python",
    )
    for i in range(len(mojo_result)):
        assert_equal(
            mojo_result[i],
            py_result_list[i],
            "compressed random data bytes should match Python",
        )


def test_compress_large_repetitive_data_python_compatibility():
    """Test that our compress implementation matches Python's results with large repetitive data.
    """
    py_zlib = Python.import_module("zlib")

    # Large repetitive data that should compress well
    test_data = String("A" * 1000).as_bytes()

    mojo_result = zlib.compress(test_data)
    py_data_bytes = to_py_bytes(test_data)
    py_result = py_zlib.compress(py_data_bytes)

    # Convert Python bytes result to list for comparison
    py_result_list = List[UInt8]()
    for i in range(len(py_result)):
        py_result_list.append(UInt8(Int(py_result[i])))

    assert_equal(
        len(mojo_result),
        len(py_result_list),
        "compressed large data length should match Python",
    )
    for i in range(len(mojo_result)):
        assert_equal(
            mojo_result[i],
            py_result_list[i],
            "compressed large data bytes should match Python",
        )

    # Verify that data was actually compressed
    assert_true(
        len(mojo_result) < len(test_data),
        "compressed data should be smaller than original",
    )


def test_compress_binary_data_python_compatibility():
    """Test that our compress implementation matches Python's results with binary data.
    """
    py_zlib = Python.import_module("zlib")

    # Binary data with all byte values 0-255
    var binary_data = [UInt8(i) for i in range(256)]

    mojo_result = zlib.compress(binary_data)
    py_data_bytes = to_py_bytes(binary_data)
    py_result = py_zlib.compress(py_data_bytes)

    # Convert Python bytes result to list for comparison
    py_result_list = List[UInt8]()
    for i in range(len(py_result)):
        py_result_list.append(UInt8(Int(py_result[i])))

    assert_equal(
        len(mojo_result),
        len(py_result_list),
        "compressed binary data length should match Python",
    )
    for i in range(len(mojo_result)):
        assert_equal(
            mojo_result[i],
            py_result_list[i],
            "compressed binary data bytes should match Python",
        )


def test_compress_multiple_random_seeds_python_compatibility():
    """Test that our compress implementation matches Python's results with different random seeds.
    """
    py_zlib = Python.import_module("zlib")

    test_seeds = [1, 123, 999, 42424242]

    for test_seed in test_seeds:
        seed(test_seed)

        # Generate random test data
        test_data = List[UInt8]()
        for _ in range(50):
            test_data.append(Byte(random_ui64(0, 255)))

        mojo_result = zlib.compress(test_data)
        py_data_bytes = to_py_bytes(test_data)
        py_result = py_zlib.compress(py_data_bytes)

        # Convert Python bytes result to list for comparison
        py_result_list = List[UInt8]()
        for i in range(len(py_result)):
            py_result_list.append(UInt8(Int(py_result[i])))

        assert_equal(
            len(mojo_result),
            len(py_result_list),
            "compressed data length should match Python for seed "
            + String(test_seed),
        )
        for i in range(len(mojo_result)):
            assert_equal(
                mojo_result[i],
                py_result_list[i],
                "compressed data bytes should match Python for seed "
                + String(test_seed),
            )
