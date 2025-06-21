"""Tests for zipfile.zlib module functionality."""

import zlib
from testing import assert_equal, assert_true


def test_adler32_basic():
    """Test basic adler32 functionality with simple data."""
    # Test with empty data
    empty_data = List[UInt8]()
    result_empty = zlib.adler32(empty_data)
    assert_equal(result_empty, 1, "adler32 of empty data should be 1")

    # Test with simple data - "hello" (expected adler32: 0x062C0215)
    hello_data = String("hello").as_bytes()

    result_hello = zlib.adler32(hello_data)
    # Known adler32 value for "hello" is 103547413 (verified against Python)
    assert_equal(
        result_hello, 103547413, "adler32 of 'hello' should be 103547413"
    )


def test_adler32_with_starting_value():
    """Test adler32 with custom starting value."""
    test_data = String("world").as_bytes()

    # Test with starting value of 12345
    result_custom = zlib.adler32(test_data, 12345)

    # The result should be different from default starting value
    result_default = zlib.adler32(test_data, 1)
    assert_true(
        result_custom != result_default,
        "Custom starting value should produce different result",
    )


def test_adler32_concatenation():
    """Test that adler32 can be computed over concatenated inputs."""
    # First part
    part1_data = String("hello").as_bytes()

    # Second part
    part2_data = String(" world").as_bytes()

    # Compute adler32 of first part
    result1 = zlib.adler32(part1_data)

    # Compute adler32 of second part using result of first as starting value
    result2 = zlib.adler32(part2_data, result1)

    # Create combined data for comparison
    combined_data = String("hello world").as_bytes()

    result_combined = zlib.adler32(combined_data)

    assert_equal(
        result2,
        result_combined,
        "Running checksum should equal single computation",
    )


def test_adler32_return_type():
    """Test that adler32 returns values in the correct range (unsigned 32-bit).
    """
    test_data = String("test").as_bytes()

    result = zlib.adler32(test_data)

    # Adler-32 should be a 32-bit unsigned value
    assert_true(result >= 0, "adler32 result should be non-negative")
    assert_true(result <= 0xFFFFFFFF, "adler32 result should fit in 32 bits")


def test_adler32_binary_data():
    """Test adler32 with binary data containing various byte values."""
    # Create data with some byte values
    binary_data = List[UInt8]()
    for i in range(10):
        binary_data.append(UInt8(i))

    result_binary = zlib.adler32(binary_data)

    # Should produce a valid checksum
    assert_true(result_binary > 0, "adler32 of binary data should be positive")
    assert_true(
        result_binary <= 0xFFFFFFFF, "adler32 result should fit in 32 bits"
    )


def test_adler32_repeated_calls():
    """Test that repeated calls with same data produce same result."""
    test_data = String("consistent").as_bytes()

    result1 = zlib.adler32(test_data)
    result2 = zlib.adler32(test_data)

    assert_equal(result1, result2, "Repeated calls should produce same result")
