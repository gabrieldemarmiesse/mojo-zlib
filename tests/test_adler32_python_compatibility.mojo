"""Test zipfile.zlib.adler32 compatibility with Python's zlib.adler32."""

import zlib
from testing import assert_equal
from python import Python
from zlib._src.utils_testing import to_py_bytes


def test_adler32_empty_data_python_compatibility():
    """Test that our adler32 implementation matches Python's results for empty data.
    """
    # Import Python's zlib
    py_zlib = Python.import_module("zlib")

    # Test empty data
    empty_data = List[UInt8]()
    mojo_result = zlib.adler32(empty_data)
    py_empty_bytes = to_py_bytes(empty_data)
    py_result = py_zlib.adler32(py_empty_bytes)
    assert_equal(
        mojo_result, Int(py_result), "adler32 empty data should match Python"
    )


def test_adler32_hello_python_compatibility():
    """Test that our adler32 implementation matches Python's results for 'hello'.
    """
    py_zlib = Python.import_module("zlib")

    # Test simple string "hello"
    hello_data = String("hello").as_bytes()
    mojo_result = zlib.adler32(hello_data)
    py_hello_bytes = to_py_bytes(hello_data)
    py_result = py_zlib.adler32(py_hello_bytes)
    assert_equal(
        mojo_result, Int(py_result), "adler32 'hello' should match Python"
    )


def test_adler32_custom_starting_value_python_compatibility():
    """Test that our adler32 implementation matches Python's results with custom starting value.
    """
    py_zlib = Python.import_module("zlib")

    # Test with custom starting value
    world_data = String("world").as_bytes()
    mojo_result = zlib.adler32(world_data, 12345)
    py_world_bytes = to_py_bytes(world_data)
    py_result = py_zlib.adler32(py_world_bytes, 12345)
    assert_equal(
        mojo_result,
        Int(py_result),
        "adler32 with custom value should match Python",
    )


def test_adler32_running_checksum_python_compatibility():
    """Test that our adler32 running checksum matches Python's results."""
    py_zlib = Python.import_module("zlib")

    # Test concatenation/running checksum
    hello_data = String("hello").as_bytes()
    hello_adler = zlib.adler32(hello_data)
    py_hello_bytes = to_py_bytes(hello_data)
    py_hello_adler = py_zlib.adler32(py_hello_bytes)
    assert_equal(hello_adler, Int(py_hello_adler), "hello adler should match")

    space_world_data = String(" world").as_bytes()
    mojo_combined = zlib.adler32(space_world_data, hello_adler)
    py_space_world_bytes = to_py_bytes(space_world_data)
    py_combined = py_zlib.adler32(py_space_world_bytes, py_hello_adler)
    assert_equal(
        mojo_combined, Int(py_combined), "running checksum should match Python"
    )


def test_adler32_direct_vs_running_checksum_python_compatibility():
    """Test that running checksum equals direct computation in both Mojo and Python.
    """
    py_zlib = Python.import_module("zlib")

    # Setup running checksum
    hello_data = String("hello").as_bytes()
    space_world_data = String(" world").as_bytes()
    hello_adler = zlib.adler32(hello_data)
    py_hello_bytes = to_py_bytes(hello_data)
    py_hello_adler = py_zlib.adler32(py_hello_bytes)

    # Compute running checksum
    mojo_combined = zlib.adler32(space_world_data, hello_adler)
    py_space_world_bytes = to_py_bytes(space_world_data)
    py_combined = py_zlib.adler32(py_space_world_bytes, py_hello_adler)

    # Verify this equals direct computation of "hello world"
    hello_world_data = String("hello world").as_bytes()
    mojo_direct = zlib.adler32(hello_world_data)
    py_hello_world_bytes = to_py_bytes(hello_world_data)
    py_direct = py_zlib.adler32(py_hello_world_bytes)

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


def test_adler32_binary_data_python_compatibility():
    """Test that our adler32 implementation matches Python's results for binary data.
    """
    py_zlib = Python.import_module("zlib")

    # Test byte values 0-9
    binary_data = List[UInt8]()
    for i in range(10):
        binary_data.append(UInt8(i))
    mojo_result = zlib.adler32(binary_data)
    py_binary_bytes = to_py_bytes(binary_data)
    py_result = py_zlib.adler32(py_binary_bytes)
    assert_equal(
        mojo_result, Int(py_result), "adler32 binary data should match Python"
    )
