"""Simple test for enhanced compressobj function with method, memLevel, and strategy parameters."""

import zlib
from testing import assert_equal


def test_compressobj_basic_functionality():
    """Test basic compressobj functionality with default parameters."""
    test_data = "Hello, World! Testing basic compression.".as_bytes()
    
    # Create compressor with defaults
    var compressor = zlib.compressobj()
    var compressed = compressor.compress(test_data)
    var final = compressor.flush()
    
    # Combine results
    var result = compressed + final
    
    # Verify we can decompress it
    var decompressed = zlib.decompress(result)
    assert_equal(len(decompressed), len(test_data), "Length should match")
    
    # Check data integrity
    for i in range(len(test_data)):
        assert_equal(decompressed[i], test_data[i], "Data should match")


def test_compressobj_with_custom_level():
    """Test compressobj with custom compression level."""
    test_data = "Testing compression with custom level.".as_bytes()
    
    # Test different compression levels
    for level in [1, 6, 9]:
        var compressor = zlib.compressobj(level)
        var compressed = compressor.compress(test_data)
        var final = compressor.flush()
        var result = compressed + final
        
        # Verify decompression works
        var decompressed = zlib.decompress(result)
        assert_equal(len(decompressed), len(test_data), "Length should match for level " + String(level))


def test_compressobj_with_custom_strategy():
    """Test compressobj with custom strategy."""
    test_data = "Testing compression with different strategies and parameters.".as_bytes()
    
    # Test with Z_FILTERED strategy
    var compressor = zlib.compressobj(
        level=6,
        method=8,  # Z_DEFLATED value
        wbits=15,
        memLevel=8,
        strategy=1  # Z_FILTERED value
    )
    
    var compressed = compressor.compress(test_data)
    var final = compressor.flush()
    var result = compressed + final
    
    # Verify decompression works
    var decompressed = zlib.decompress(result)
    assert_equal(len(decompressed), len(test_data), "Length should match for custom strategy")
    for i in range(len(test_data)):
        assert_equal(decompressed[i], test_data[i], "Data should match for custom strategy")


def main():
    """Run all simple tests."""
    test_compressobj_basic_functionality()
    test_compressobj_with_custom_level()
    test_compressobj_with_custom_strategy()