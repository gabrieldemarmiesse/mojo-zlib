"""Tests for zipfile.zlib.crc32 functionality."""

import zlib
from testing import assert_equal, assert_true


def test_crc32_basic():
    """Test basic CRC32 functionality with simple data."""
    # Test with empty data
    empty_data = List[UInt8]()
    result_empty = zlib.crc32(empty_data)
    assert_equal(result_empty, 0, "crc32 of empty data should be 0")

    # Test with simple data - "hello"
    hello_data = String("hello").as_bytes()
    result_hello = zlib.crc32(hello_data)
    # Known CRC32 value for "hello" is 0x3610a686 = 907060870
    assert_equal(
        result_hello, 907060870, "crc32 of 'hello' should be 907060870"
    )


def test_crc32_with_starting_value():
    """Test CRC32 with custom starting value."""
    test_data = String("world").as_bytes()

    # Test with starting value of 12345
    result_custom = zlib.crc32(test_data, 12345)

    # The result should be different from default starting value
    result_default = zlib.crc32(test_data, 0)
    assert_true(
        result_custom != result_default,
        "Custom starting value should produce different result",
    )


def test_crc32_concatenation():
    """Test that CRC32 can be computed over concatenated inputs."""
    # First part
    part1_data = String("hello").as_bytes()

    # Second part
    part2_data = String(" world").as_bytes()

    # Compute CRC32 of first part
    result1 = zlib.crc32(part1_data)

    # Compute CRC32 of second part using result of first as starting value
    result2 = zlib.crc32(part2_data, result1)

    # Create combined data for comparison
    combined_data = String("hello world").as_bytes()

    result_combined = zlib.crc32(combined_data)

    assert_equal(
        result2,
        result_combined,
        "Running checksum should equal single computation",
    )


def test_crc32_return_type():
    """Test that CRC32 returns values in the correct range (unsigned 32-bit)."""
    test_data = String("test").as_bytes()

    result = zlib.crc32(test_data)

    # CRC-32 should be a 32-bit unsigned value
    assert_true(result >= 0, "crc32 result should be non-negative")
    assert_true(result <= 0xFFFFFFFF, "crc32 result should fit in 32 bits")


def test_crc32_binary_data():
    """Test CRC32 with binary data containing various byte values."""
    # Create data with some byte values
    binary_data = List[UInt8]()
    for i in range(10):
        binary_data.append(UInt8(i))

    result_binary = zlib.crc32(binary_data)

    # Should produce a valid checksum
    assert_true(
        result_binary >= 0, "crc32 of binary data should be non-negative"
    )
    assert_true(
        result_binary <= 0xFFFFFFFF, "crc32 result should fit in 32 bits"
    )


def test_crc32_repeated_calls():
    """Test that repeated calls with same data produce same result."""
    test_data = String("consistent").as_bytes()

    result1 = zlib.crc32(test_data)
    result2 = zlib.crc32(test_data)

    assert_equal(result1, result2, "Repeated calls should produce same result")


def test_crc32_known_values():
    """Test CRC32 with known values to verify correctness."""
    # Test empty string
    empty_data = String("").as_bytes()
    result = zlib.crc32(empty_data)
    assert_equal(result, 0, "crc32 of empty string should be 0")

    # Test single character "a"
    a_data = String("a").as_bytes()
    result = zlib.crc32(a_data)
    assert_equal(result, 0xE8B7BE43, "crc32 of 'a' should be 0xe8b7be43")

    # Test "abc"
    abc_data = String("abc").as_bytes()
    result = zlib.crc32(abc_data)
    assert_equal(result, 0x352441C2, "crc32 of 'abc' should be 0x352441c2")

    # Test "123456789"
    digits_data = String("123456789").as_bytes()
    result = zlib.crc32(digits_data)
    assert_equal(
        result, 0xCBF43926, "crc32 of '123456789' should be 0xcbf43926"
    )


def test_crc32_incremental():
    """Test incremental CRC32 computation."""
    # Test building up a string incrementally
    base_data = String("The quick brown").as_bytes()
    base_crc = zlib.crc32(base_data)

    append_data = String(" fox jumps").as_bytes()
    incremental_crc = zlib.crc32(append_data, base_crc)

    # Compare with direct computation
    full_data = String("The quick brown fox jumps").as_bytes()
    direct_crc = zlib.crc32(full_data)

    assert_equal(
        incremental_crc,
        direct_crc,
        "Incremental CRC should match direct computation",
    )


def test_crc32_all_bytes():
    """Test CRC32 with all possible byte values."""
    # Create data with all byte values 0-255
    all_bytes = List[UInt8]()
    for i in range(256):
        all_bytes.append(UInt8(i))

    result = zlib.crc32(all_bytes)

    # Should produce a valid, consistent result
    assert_true(result >= 0, "crc32 of all bytes should be non-negative")
    assert_true(result <= 0xFFFFFFFF, "crc32 result should fit in 32 bits")

    # Test it's consistent
    result2 = zlib.crc32(all_bytes)
    assert_equal(result, result2, "CRC32 of all bytes should be consistent")
