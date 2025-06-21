"""Integration tests for real-world zlib usage patterns."""

import zlib
from zlib._src.utils_testing import (
    to_py_bytes,
    to_mojo_bytes,
    assert_lists_are_equal,
)
from testing import assert_equal, assert_true
from python import Python


def test_web_content_simulation():
    """Test compressing/decompressing web-like content."""
    # Simulate HTML content with repeated patterns
    html_content = """<!DOCTYPE html>
<html>
<head>
    <title>Test Page</title>
    <meta charset="utf-8">
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Welcome to Test Page</h1>
        </div>
        <div class="content">
            <p>This is test content that simulates a typical web page.</p>
            <p>It contains repeated HTML tags and structure.</p>
        </div>
    </div>
</body>
</html>"""

    var html_bytes = html_content.as_bytes()

    # Test different compression levels for web content
    var levels = List[Int]()
    levels.append(1)  # Fast
    levels.append(6)  # Default
    levels.append(9)  # Best

    for level in levels:
        var compressed = zlib.compress(html_bytes, level=level)
        var decompressed = zlib.decompress(compressed)

        assert_lists_are_equal(
            html_bytes, decompressed, "HTML content level " + String(level)
        )

        # Check compression ratio (HTML should compress well)
        var ratio = Float64(len(compressed)) / Float64(len(html_bytes))
        assert_true(
            ratio < 0.8, "HTML should compress to less than 80% of original"
        )


def test_binary_data_patterns():
    """Test with various binary data patterns."""
    # Pattern 1: All zeros (should compress extremely well)
    var zeros = List[UInt8]()
    for _ in range(1000):
        zeros.append(0)

    # Pattern 2: Alternating bytes (should compress moderately)
    var alternating = List[UInt8]()
    for i in range(1000):
        alternating.append(UInt8(i % 2))

    # Pattern 3: Text-like data with repeated words
    var text_pattern = "the quick brown fox jumps over the lazy dog " * 20
    var text_bytes = List[UInt8]()
    for byte in text_pattern.as_bytes():
        text_bytes.append(byte)

    var patterns = List[List[UInt8]]()
    patterns.append(zeros)
    patterns.append(alternating)
    patterns.append(text_bytes)

    var pattern_names = List[String]()
    pattern_names.append("zeros")
    pattern_names.append("alternating")
    pattern_names.append("text_pattern")

    for i in range(len(patterns)):
        var pattern = patterns[i]
        var name = pattern_names[i]

        var compressed = zlib.compress(pattern)
        var decompressed = zlib.decompress(compressed)

        assert_lists_are_equal(
            pattern, decompressed, name + " pattern should roundtrip"
        )

        # Check compression effectiveness
        var ratio = Float64(len(compressed)) / Float64(len(pattern))
        if name == "zeros":
            assert_true(ratio < 0.1, "Zeros should compress very well")
        elif name == "text_pattern":
            assert_true(ratio < 0.7, "Repeated text should compress well")


def test_mixed_format_compatibility():
    """Test compatibility with different compression formats."""
    test_data = (
        "Mixed format compatibility test data with some repeated patterns."
        .as_bytes()
    )

    var formats = List[Tuple[Int, String]]()
    formats.append((15, String("zlib_format")))
    formats.append((-15, String("raw_deflate")))

    for format_info in formats:
        var wbits = format_info[0]
        var format_name = format_info[1]

        # Test with our implementation
        var compressed = zlib.compress(test_data, wbits=wbits)
        var decompressed = zlib.decompress(compressed, wbits=wbits)

        assert_lists_are_equal(
            test_data, decompressed, format_name + " should work"
        )


def test_checksum_incremental_usage():
    """Test checksums in incremental/streaming scenarios."""
    # Simulate computing checksums for streaming data
    var data_parts = List[List[UInt8]]()

    var part1 = List[UInt8]()
    for byte in "Hello, ".as_bytes():
        part1.append(byte)
    data_parts.append(part1)

    var part2 = List[UInt8]()
    for byte in "World! ".as_bytes():
        part2.append(byte)
    data_parts.append(part2)

    # Combine for reference
    var full_data = List[UInt8]()
    for part in data_parts:
        for byte in part:
            full_data.append(byte)

    # Compute checksums incrementally
    var crc_incremental: UInt32 = 0
    var adler_incremental: UInt32 = 1

    for part in data_parts:
        crc_incremental = zlib.crc32(part, crc_incremental)
        adler_incremental = zlib.adler32(part, adler_incremental)

    # Compute checksums all at once
    var crc_full = zlib.crc32(full_data)
    var adler_full = zlib.adler32(full_data)

    assert_equal(
        crc_incremental,
        crc_full,
        "Incremental CRC32 should match full computation",
    )
    assert_equal(
        adler_incremental,
        adler_full,
        "Incremental Adler32 should match full computation",
    )


def test_real_world_json_data():
    """Test with JSON-like data that's common in web applications."""
    json_data = """{
    "users": [
        {
            "id": 1,
            "name": "John Doe",
            "email": "john@example.com"
        },
        {
            "id": 2,
            "name": "Jane Smith", 
            "email": "jane@example.com"
        }
    ],
    "metadata": {
        "version": "1.0",
        "total_users": 2
    }
}"""

    var json_bytes = json_data.as_bytes()

    # Test both streaming and single-shot compression
    var single_shot_compressed = zlib.compress(json_bytes)
    var single_shot_decompressed = zlib.decompress(single_shot_compressed)

    assert_lists_are_equal(
        json_bytes, single_shot_decompressed, "JSON single-shot should work"
    )

    # Test streaming
    var compressor = zlib.compressobj()
    var streaming_compressed = (
        compressor.compress(json_bytes) + compressor.flush()
    )
    var streaming_decompressed = zlib.decompress(streaming_compressed)

    assert_lists_are_equal(
        json_bytes, streaming_decompressed, "JSON streaming should work"
    )

    # Both methods should produce same result
    assert_lists_are_equal(
        single_shot_compressed,
        streaming_compressed,
        "JSON compression methods should match",
    )


def main():
    """Run all integration tests."""
    test_web_content_simulation()
    test_binary_data_patterns()
    test_mixed_format_compatibility()
    test_checksum_incremental_usage()
    test_real_world_json_data()
