"""Test zipfile.zlib.crc32 compatibility with Python's zlib.crc32."""

import zlib
from testing import assert_equal
from python import Python
from zlib._src.utils_testing import to_py_bytes


def test_crc32_empty_data_python_compatibility():
    """Test that our crc32 implementation matches Python's results for empty data.
    """
    # Import Python's zlib
    py_zlib = Python.import_module("zlib")

    # Test empty data
    empty_data = List[UInt8]()
    mojo_result = zlib.crc32(empty_data)
    py_empty_bytes = to_py_bytes(empty_data)
    py_result = py_zlib.crc32(py_empty_bytes)
    assert_equal(
        Int(mojo_result), Int(py_result), "crc32 empty data should match Python"
    )


def test_crc32_hello_python_compatibility():
    """Test that our crc32 implementation matches Python's results for 'hello'.
    """
    py_zlib = Python.import_module("zlib")

    # Test simple string "hello"
    hello_data = String("hello").as_bytes()
    mojo_result = zlib.crc32(hello_data)
    py_hello_bytes = to_py_bytes(hello_data)
    py_result = py_zlib.crc32(py_hello_bytes)
    assert_equal(
        Int(mojo_result), Int(py_result), "crc32 'hello' should match Python"
    )


def test_crc32_custom_starting_value_python_compatibility():
    """Test that our crc32 implementation matches Python's results with custom starting value.
    """
    py_zlib = Python.import_module("zlib")

    # Test with custom starting value
    world_data = String("world").as_bytes()
    mojo_result = zlib.crc32(world_data, 12345)
    py_world_bytes = to_py_bytes(world_data)
    py_result = py_zlib.crc32(py_world_bytes, 12345)
    assert_equal(
        Int(mojo_result),
        Int(py_result),
        "crc32 with custom value should match Python",
    )


def test_crc32_running_checksum_python_compatibility():
    """Test that our crc32 running checksum matches Python's results."""
    py_zlib = Python.import_module("zlib")

    # Test concatenation/running checksum
    hello_data = String("hello").as_bytes()
    hello_crc = zlib.crc32(hello_data)
    py_hello_bytes = to_py_bytes(hello_data)
    py_hello_crc = py_zlib.crc32(py_hello_bytes)
    assert_equal(Int(hello_crc), Int(py_hello_crc), "hello crc should match")

    space_world_data = String(" world").as_bytes()
    mojo_combined = zlib.crc32(space_world_data, hello_crc)
    py_space_world_bytes = to_py_bytes(space_world_data)
    py_combined = py_zlib.crc32(py_space_world_bytes, py_hello_crc)
    assert_equal(
        Int(mojo_combined),
        Int(py_combined),
        "running checksum should match Python",
    )


def test_crc32_direct_vs_running_checksum_python_compatibility():
    """Test that running checksum equals direct computation in both Mojo and Python.
    """
    py_zlib = Python.import_module("zlib")

    # Setup running checksum
    hello_data = String("hello").as_bytes()
    space_world_data = String(" world").as_bytes()
    hello_crc = zlib.crc32(hello_data)
    py_hello_bytes = to_py_bytes(hello_data)
    py_hello_crc = py_zlib.crc32(py_hello_bytes)

    # Compute running checksum
    mojo_combined = zlib.crc32(space_world_data, hello_crc)
    py_space_world_bytes = to_py_bytes(space_world_data)
    py_combined = py_zlib.crc32(py_space_world_bytes, py_hello_crc)

    # Verify this equals direct computation of "hello world"
    hello_world_data = String("hello world").as_bytes()
    mojo_direct = zlib.crc32(hello_world_data)
    py_hello_world_bytes = to_py_bytes(hello_world_data)
    py_direct = py_zlib.crc32(py_hello_world_bytes)

    assert_equal(
        mojo_combined,
        mojo_direct,
        "running checksum should equal direct computation",
    )
    assert_equal(
        Int(py_combined),
        Int(py_direct),
        "Python running checksum should equal direct",
    )


def test_crc32_binary_data_python_compatibility():
    """Test that our crc32 implementation matches Python's results for binary data.
    """
    py_zlib = Python.import_module("zlib")

    # Test byte values 0-9
    binary_data = List[UInt8]()
    for i in range(10):
        binary_data.append(UInt8(i))
    mojo_result = zlib.crc32(binary_data)
    py_binary_bytes = to_py_bytes(binary_data)
    py_result = py_zlib.crc32(py_binary_bytes)
    assert_equal(
        Int(mojo_result),
        Int(py_result),
        "crc32 binary data should match Python",
    )


def test_crc32_known_values_python_compatibility():
    """Test CRC32 known values against Python."""
    py_zlib = Python.import_module("zlib")

    test_strings = ["", "a", "abc", "123456789", "The quick brown fox"]

    for test_string in test_strings:
        data = String(test_string).as_bytes()
        mojo_result = zlib.crc32(data)

        py_bytes = to_py_bytes(data)
        py_result = py_zlib.crc32(py_bytes)

        assert_equal(
            Int(mojo_result),
            Int(py_result),
            "crc32 of '" + test_string + "' should match Python",
        )


def test_crc32_larger_data_python_compatibility():
    """Test CRC32 with larger data against Python."""
    py_zlib = Python.import_module("zlib")

    # Create larger test data
    test_string = "The quick brown fox jumps over the lazy dog. " * 50
    data = String(test_string).as_bytes()
    mojo_result = zlib.crc32(data)

    # Create Python string and compute CRC32
    py_bytes = to_py_bytes(data)
    py_result = py_zlib.crc32(py_bytes)

    assert_equal(
        Int(mojo_result),
        Int(py_result),
        "crc32 of large data should match Python",
    )
