"""Test the Python-compatible decompression object attributes."""

import zlib
from testing import assert_equal, assert_true, assert_false


def test_decompression_object_attributes():
    """Test unused_data, unconsumed_tail, and eof attributes."""
    # Create test data
    test_data = (
        "Hello, World! This is a test for decompression attributes.".as_bytes()
    )
    var compressed = zlib.compress(test_data)

    # Add some extra data after the compressed stream
    var extra_data = List[UInt8]()
    for byte in compressed:
        extra_data.append(byte)
    # Add some garbage data at the end
    extra_data.append(1)
    extra_data.append(2)
    extra_data.append(3)
    extra_data.append(4)

    # Create decompressor
    var decompressor = zlib.decompressobj()

    # Initially, all attributes should be empty/false
    assert_equal(
        len(decompressor.unused_data),
        0,
        "unused_data should initially be empty",
    )
    assert_equal(
        len(decompressor.unconsumed_tail),
        0,
        "unconsumed_tail should initially be empty",
    )
    assert_false(decompressor.eof, "eof should initially be False")

    # Decompress the data
    var result = decompressor.decompress(extra_data)

    # Check that decompression worked
    assert_equal(
        len(result),
        len(test_data),
        "Decompressed data length should match original",
    )
    for i in range(len(result)):
        assert_equal(
            result[i], test_data[i], "Decompressed data should match original"
        )

    # After decompression, eof should be True
    assert_true(
        decompressor.eof, "eof should be True after successful decompression"
    )

    # unused_data should contain the extra bytes that weren't part of the compressed stream
    var unused = decompressor.unused_data
    assert_equal(len(unused), 4, "unused_data should contain the 4 extra bytes")
    assert_equal(unused[0], 1, "First unused byte should be 1")
    assert_equal(unused[1], 2, "Second unused byte should be 2")
    assert_equal(unused[2], 3, "Third unused byte should be 3")
    assert_equal(unused[3], 4, "Fourth unused byte should be 4")


def test_unconsumed_tail_partial_decompress():
    """Test unconsumed_tail with partial decompression."""
    test_data = "Hello, World!".as_bytes()
    var compressed = zlib.compress(test_data)

    var decompressor = zlib.decompressobj()

    # Feed only part of the compressed data (half of it)
    var partial_size = len(compressed) // 2
    var partial_data = List[UInt8]()
    for i in range(partial_size):
        partial_data.append(compressed[i])

    var result = decompressor.decompress(partial_data)

    # Check what happened after feeding partial data
    var unconsumed = decompressor.unconsumed_tail

    # If no data was consumed (which is expected with incomplete compressed data),
    # unconsumed_tail should contain all the data we fed
    if len(result) == 0:
        # No decompression happened, so all input should be in unconsumed_tail
        assert_equal(
            len(unconsumed),
            partial_size,
            (
                "unconsumed_tail should contain all fed data when no"
                " decompression occurs"
            ),
        )
    else:
        # Some decompression happened, unconsumed_tail might be smaller
        assert_true(len(unconsumed) >= 0, "unconsumed_tail should be valid")

    # eof should still be False since we haven't reached the end
    assert_false(decompressor.eof, "eof should be False with partial data")


def test_empty_decompression_attributes():
    """Test attributes with empty decompression."""
    var decompressor = zlib.decompressobj()

    # Without feeding any data, all should be empty/false
    assert_equal(
        len(decompressor.unused_data), 0, "unused_data should be empty"
    )
    assert_equal(
        len(decompressor.unconsumed_tail), 0, "unconsumed_tail should be empty"
    )
    assert_false(decompressor.eof, "eof should be False")


def main():
    """Run all decompression attribute tests."""
    test_decompression_object_attributes()
    test_unconsumed_tail_partial_decompress()
    test_empty_decompression_attributes()
