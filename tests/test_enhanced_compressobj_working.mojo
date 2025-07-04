"""Working test for enhanced compressobj functionality."""

import zlib
from testing import assert_equal


def test_compressobj_with_all_parameters():
    """Test compressobj with all parameters using explicit values."""
    test_data = "Testing enhanced compressobj with all parameters.".as_bytes()

    # Test with explicit parameter values (not constants to avoid type issues)
    var compressor = zlib.compressobj(
        level=6,  # compression level
        method=8,  # Z_DEFLATED
        wbits=15,  # window bits
        memLevel=8,  # memory level
        strategy=0,  # Z_DEFAULT_STRATEGY
    )

    var compressed = compressor.compress(test_data)
    var final = compressor.flush()
    var result = compressed + final

    # Verify decompression works
    var decompressed = zlib.decompress(result)
    assert_equal(len(decompressed), len(test_data), "Length should match")

    for i in range(len(test_data)):
        assert_equal(decompressed[i], test_data[i], "Data should match")


def test_different_strategies():
    """Test different compression strategies with explicit values."""
    test_data = "Testing different compression strategies.".as_bytes()

    # Test different strategies: 0=default, 1=filtered, 2=huffman_only, 3=rle, 4=fixed
    var strategies = List[Int]()
    strategies.append(0)  # Z_DEFAULT_STRATEGY
    strategies.append(1)  # Z_FILTERED
    strategies.append(2)  # Z_HUFFMAN_ONLY
    strategies.append(3)  # Z_RLE
    strategies.append(4)  # Z_FIXED

    for strategy in strategies:
        var compressor = zlib.compressobj(
            level=6, method=8, wbits=15, memLevel=8, strategy=strategy
        )

        var compressed = compressor.compress(test_data)
        var final = compressor.flush()
        var result = compressed + final

        # Verify decompression works
        var decompressed = zlib.decompress(result)
        assert_equal(
            len(decompressed),
            len(test_data),
            "Strategy " + String(strategy) + " should work",
        )


def test_different_memory_levels():
    """Test different memory levels."""
    test_data = "Testing different memory levels.".as_bytes()

    # Test memory levels 1-9
    for memLevel in range(1, 10):
        var compressor = zlib.compressobj(
            level=6, method=8, wbits=15, memLevel=memLevel, strategy=0
        )

        var compressed = compressor.compress(test_data)
        var final = compressor.flush()
        var result = compressed + final

        # Verify decompression works
        var decompressed = zlib.decompress(result)
        assert_equal(
            len(decompressed),
            len(test_data),
            "Memory level " + String(memLevel) + " should work",
        )


def test_parameter_validation():
    """Test that different valid parameter combinations work."""
    test_data = "Testing parameter validation.".as_bytes()

    # Test edge cases for valid parameters
    var configs = List[Tuple[Int, Int, Int, Int, Int]]()
    configs.append((0, 8, 9, 1, 0))  # Min compression, min window, min memory
    configs.append((9, 8, 15, 9, 4))  # Max compression, max window, max memory
    configs.append((6, 8, 12, 5, 2))  # Middle values

    for config in configs:
        var level = config[0]
        var method = config[1]
        var wbits = config[2]
        var memLevel = config[3]
        var strategy = config[4]

        var compressor = zlib.compressobj(
            level, method, wbits, memLevel, strategy
        )
        var compressed = compressor.compress(test_data)
        var final = compressor.flush()
        var result = compressed + final

        # Verify decompression works
        var decompressed = zlib.decompress(result, wbits=wbits)
        assert_equal(
            len(decompressed), len(test_data), "Configuration should work"
        )
