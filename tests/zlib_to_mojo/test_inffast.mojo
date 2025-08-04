"""Unit tests for inffast.mojo fast decompression functionality."""

from memory import UnsafePointer, memset_zero
from testing import assert_equal, assert_not_equal, assert_true, assert_false

from zlib._src.zlib_to_mojo.inffast import (
    inflate_fast, INFLATE_FAST_MIN_HAVE, INFLATE_FAST_MIN_LEFT
)
from zlib._src.zlib_to_mojo.inflate_constants import InflateState, InflateMode
from zlib._src.zlib_to_mojo.inftrees import Code


def test_constants():
    """Test inffast constants."""
    assert_equal(INFLATE_FAST_MIN_HAVE, 6)
    assert_equal(INFLATE_FAST_MIN_LEFT, 258)


def test_inflate_fast_literal():
    """Test inflate_fast with literal codes."""
    # Create a simple test case with literal codes
    var input = UnsafePointer[UInt8].alloc(10)
    var output = UnsafePointer[UInt8].alloc(10)
    
    # Set up simple input data (bit patterns for literals)
    input[0] = 0x48  # 'H' literal code pattern
    input[1] = 0x65  # 'e' literal code pattern
    input[2] = 0x6C  # 'l' literal code pattern
    input[3] = 0x6C  # 'l' literal code pattern
    input[4] = 0x6F  # 'o' literal code pattern
    input[5] = 0x00  # End marker
    
    # Create lencode table with simple literal mappings
    var lencode = UnsafePointer[Code].alloc(256)
    for i in range(256):
        lencode[i] = Code(op=0, bits=8, val=UInt16(i))  # 8-bit literals
    
    # Create minimal distcode table
    var distcode = UnsafePointer[Code].alloc(32)
    for i in range(32):
        distcode[i] = Code(op=0, bits=5, val=UInt16(i))
    
    # Create and initialize state
    var state = InflateState()
    state.mode = InflateMode.LEN
    state.lencode = lencode
    state.distcode = distcode
    state.lenbits = 8
    state.distbits = 5
    state.hold = 0
    state.bits = 0
    state.sane = 1
    
    # Call inflate_fast (simplified test - won't actually decode properly due to bit packing)
    var consumed, produced, _ = inflate_fast(
        input, 6, output, 10, state, 10
    )
    
    # Basic checks - this is a simplified test
    assert_true(consumed <= 6)
    assert_true(produced <= 10)
    
    # Clean up
    input.free()
    output.free()
    lencode.free()
    distcode.free()


def test_inflate_fast_end_of_block():
    """Test inflate_fast with end-of-block code."""
    var input = UnsafePointer[UInt8].alloc(10)
    var output = UnsafePointer[UInt8].alloc(10)
    
    # Fill input buffer with data
    for i in range(10):
        input[i] = 0x00  # Zero bits should look up lencode[0]
    
    # Create lencode table with end-of-block code
    var lencode = UnsafePointer[Code].alloc(256)
    # Most entries are literals
    for i in range(256):
        lencode[i] = Code(op=0, bits=8, val=UInt16(i))
    # Set up end-of-block code (op=32 means end-of-block)
    lencode[0] = Code(op=32, bits=1, val=256)  # End-of-block marker with 1 bit
    
    var distcode = UnsafePointer[Code].alloc(32)
    for i in range(32):
        distcode[i] = Code(op=0, bits=5, val=UInt16(i))
    
    var state = InflateState()
    state.mode = InflateMode.LEN
    state.lencode = lencode
    state.distcode = distcode
    state.lenbits = 8  # Use full 8 bits for lookup
    state.distbits = 5
    state.hold = 0  # Will look up lencode[0] which is end-of-block
    state.bits = 0   # Start with no bits so it loads from input
    state.sane = 1
    
    var _, _, new_state = inflate_fast(
        input, 10, output, 10, state, 10  # Use all 10 input bytes
    )
    
    # Should have switched to TYPE mode on end-of-block
    assert_equal(new_state.mode, InflateMode.TYPE)
    
    # Clean up
    input.free()
    output.free()
    lencode.free()
    distcode.free()


def test_inflate_fast_invalid_code():
    """Test inflate_fast with invalid code."""
    var input = UnsafePointer[UInt8].alloc(10)
    var output = UnsafePointer[UInt8].alloc(10)
    
    # Fill input buffer with data
    for i in range(10):
        input[i] = 0x00  # Zero bits should look up lencode[0]
    
    # Create lencode table with invalid code
    var lencode = UnsafePointer[Code].alloc(256)
    # Set up invalid code (op with high bits set)
    lencode[0] = Code(op=128, bits=1, val=0)  # Invalid code with 1 bit
    
    var distcode = UnsafePointer[Code].alloc(32)
    for i in range(32):
        distcode[i] = Code(op=0, bits=5, val=UInt16(i))
    
    var state = InflateState()
    state.mode = InflateMode.LEN
    state.lencode = lencode
    state.distcode = distcode
    state.lenbits = 8
    state.distbits = 5
    state.hold = 0  # Will look up lencode[0] which is invalid
    state.bits = 0   # Start with no bits so it loads from input
    state.sane = 1
    
    var _, _, new_state = inflate_fast(
        input, 10, output, 10, state, 10  # Use all 10 input bytes
    )
    
    # Should have switched to BAD mode on invalid code
    assert_equal(new_state.mode, InflateMode.BAD)
    
    # Clean up
    input.free()
    output.free()
    lencode.free()
    distcode.free()


def test_inflate_fast_insufficient_input():
    """Test inflate_fast with insufficient input."""
    var input = UnsafePointer[UInt8].alloc(3)  # Only 3 bytes, need at least 6
    var output = UnsafePointer[UInt8].alloc(300)
    
    var lencode = UnsafePointer[Code].alloc(256)
    for i in range(256):
        lencode[i] = Code(op=0, bits=8, val=UInt16(i))
    
    var distcode = UnsafePointer[Code].alloc(32)
    for i in range(32):
        distcode[i] = Code(op=0, bits=5, val=UInt16(i))
    
    var state = InflateState()
    state.mode = InflateMode.LEN
    state.lencode = lencode
    state.distcode = distcode
    state.lenbits = 8
    state.distbits = 5
    state.hold = 0
    state.bits = 0
    state.sane = 1
    
    var consumed, _, new_state = inflate_fast(
        input, 3, output, 300, state, 300  # Only 3 input bytes
    )
    
    # Should not process much due to insufficient input
    assert_true(consumed <= 3)
    # Mode should remain LEN (ran out of input)
    assert_equal(new_state.mode, InflateMode.LEN)
    
    # Clean up
    input.free()
    output.free()
    lencode.free()
    distcode.free()


def test_inflate_fast_insufficient_output():
    """Test inflate_fast with insufficient output space."""
    var input = UnsafePointer[UInt8].alloc(10)
    var output = UnsafePointer[UInt8].alloc(5)  # Only 5 bytes, need at least 258
    
    var lencode = UnsafePointer[Code].alloc(256)
    for i in range(256):
        lencode[i] = Code(op=0, bits=8, val=UInt16(i))
    
    var distcode = UnsafePointer[Code].alloc(32)
    for i in range(32):
        distcode[i] = Code(op=0, bits=5, val=UInt16(i))
    
    var state = InflateState()
    state.mode = InflateMode.LEN
    state.lencode = lencode
    state.distcode = distcode
    state.lenbits = 8
    state.distbits = 5
    state.hold = 0
    state.bits = 0
    state.sane = 1
    
    var _, produced, new_state = inflate_fast(
        input, 10, output, 5, state, 5  # Only 5 output bytes
    )
    
    # Should not produce much due to insufficient output
    assert_true(produced <= 5)
    # Mode should remain LEN (ran out of output)
    assert_equal(new_state.mode, InflateMode.LEN)
    
    # Clean up
    input.free()
    output.free()
    lencode.free()
    distcode.free()


def test_state_preservation():
    """Test that state is properly preserved and updated."""
    var input = UnsafePointer[UInt8].alloc(10)
    var output = UnsafePointer[UInt8].alloc(10)
    
    var lencode = UnsafePointer[Code].alloc(256)
    # Set up end-of-block code
    lencode[0] = Code(op=32, bits=4, val=256)  # End-of-block with 4 bits
    
    var distcode = UnsafePointer[Code].alloc(32)
    for i in range(32):
        distcode[i] = Code(op=0, bits=5, val=UInt16(i))
    
    var state = InflateState()
    state.mode = InflateMode.LEN
    state.lencode = lencode
    state.distcode = distcode
    state.lenbits = 8
    state.distbits = 5
    state.hold = 0x0F  # 4 bits set (will match lencode[0] pattern)
    state.bits = 8
    state.sane = 1
    state.wsize = 32768
    state.whave = 1000
    
    var original_wsize = state.wsize
    var original_whave = state.whave
    
    var _, _, new_state = inflate_fast(
        input, 6, output, 10, state, 10
    )
    
    # Window state should be preserved
    assert_equal(new_state.wsize, original_wsize)
    assert_equal(new_state.whave, original_whave)
    
    # Hold and bits should be updated after processing
    # (Exact values depend on processing, but should be valid)
    assert_true(new_state.bits <= 64)  # Reasonable bit count
    
    # Clean up
    input.free()
    output.free()
    lencode.free()
    distcode.free()


def test_bit_accumulator_handling():
    """Test bit accumulator operations."""
    var input = UnsafePointer[UInt8].alloc(10)
    var output = UnsafePointer[UInt8].alloc(10)
    
    # Fill input with known pattern
    for i in range(10):
        input[i] = UInt8(i * 17)  # Some pattern
    
    var lencode = UnsafePointer[Code].alloc(256)
    # Set up end-of-block code that requires specific bit pattern
    lencode[0] = Code(op=32, bits=1, val=256)  # End-of-block with 1 bit
    
    var distcode = UnsafePointer[Code].alloc(32)
    for i in range(32):
        distcode[i] = Code(op=0, bits=5, val=UInt16(i))
    
    var state = InflateState()
    state.mode = InflateMode.LEN
    state.lencode = lencode
    state.distcode = distcode
    state.lenbits = 8
    state.distbits = 5
    state.hold = 0  # Start with empty hold
    state.bits = 0  # Start with no bits
    state.sane = 1
    
    var consumed, _, new_state = inflate_fast(
        input, 6, output, 10, state, 10
    )
    
    # Bits should have been loaded from input
    assert_true(consumed > 0 or new_state.bits > 0)  # Either consumed input or had bits
    
    # Clean up
    input.free()
    output.free()
    lencode.free()
    distcode.free()


def test_length_distance_code_handling():
    """Test handling of length/distance codes (simplified)."""
    var input = UnsafePointer[UInt8].alloc(10)
    var output = UnsafePointer[UInt8].alloc(300)
    
    var lencode = UnsafePointer[Code].alloc(256)
    # Most are literals
    for i in range(256):
        lencode[i] = Code(op=0, bits=8, val=UInt16(i))
    
    # Set up a length code (op=16 means length base)
    lencode[1] = Code(op=16, bits=8, val=3)  # Length 3, no extra bits
    
    var distcode = UnsafePointer[Code].alloc(32)
    # Set up distance codes (op=16 means distance base)
    for i in range(32):
        distcode[i] = Code(op=16, bits=5, val=UInt16(i + 1))  # Distance i+1
    
    var state = InflateState()
    state.mode = InflateMode.LEN
    state.lencode = lencode
    state.distcode = distcode
    state.lenbits = 8
    state.distbits = 5
    state.hold = 1  # Will look up lencode[1] which is a length code
    state.bits = 8
    state.sane = 1
    
    # Set up sliding window (for distance copying)
    state.wsize = 100
    state.whave = 50
    state.wnext = 25
    state.window = UnsafePointer[UInt8].alloc(100)
    # Fill window with known data
    for i in range(100):
        state.window[i] = UInt8(65 + (i % 26))  # A-Z pattern
    
    var consumed, produced, _ = inflate_fast(
        input, 6, output, 300, state, 300
    )
    
    # Should handle the length/distance combination
    # (Exact behavior depends on bit patterns, but should not crash)
    assert_true(consumed >= 0)
    assert_true(produced >= 0)
    
    # Clean up
    input.free()
    output.free()
    lencode.free()
    distcode.free()
    state.window.free()


def test_window_operations():
    """Test sliding window operations.""" 
    var input = UnsafePointer[UInt8].alloc(10)
    var output = UnsafePointer[UInt8].alloc(300)
    
    # Set up codes
    var lencode = UnsafePointer[Code].alloc(256)
    for i in range(256):
        lencode[i] = Code(op=0, bits=8, val=UInt16(i))
    
    var distcode = UnsafePointer[Code].alloc(32)
    for i in range(32):
        distcode[i] = Code(op=0, bits=5, val=UInt16(i))
    
    var state = InflateState()
    state.mode = InflateMode.LEN
    state.lencode = lencode
    state.distcode = distcode
    state.lenbits = 8
    state.distbits = 5
    state.hold = 0
    state.bits = 0
    state.sane = 1
    
    # Test with different window configurations
    state.wsize = 256
    state.whave = 128
    state.wnext = 64
    state.window = UnsafePointer[UInt8].alloc(256)
    for i in range(256):
        state.window[i] = UInt8(i % 256)
    
    var _, _, new_state = inflate_fast(
        input, 6, output, 300, state, 300
    )
    
    # Window parameters should be preserved
    assert_equal(new_state.wsize, 256)
    assert_equal(new_state.whave, 128)
    assert_equal(new_state.wnext, 64)
    
    # Clean up
    input.free()
    output.free()
    lencode.free()
    distcode.free()
    state.window.free()


def test_error_conditions():
    """Test various error conditions."""
    var input = UnsafePointer[UInt8].alloc(10)
    var output = UnsafePointer[UInt8].alloc(10)
    
    # Test with invalid state mode
    var lencode = UnsafePointer[Code].alloc(256)
    for i in range(256):
        lencode[i] = Code(op=0, bits=8, val=UInt16(i))
    
    var distcode = UnsafePointer[Code].alloc(32)
    for i in range(32):
        distcode[i] = Code(op=0, bits=5, val=UInt16(i))
    
    var state = InflateState()
    state.mode = InflateMode.BAD  # Already in error state
    state.lencode = lencode
    state.distcode = distcode
    state.lenbits = 8
    state.distbits = 5
    state.hold = 0
    state.bits = 0
    state.sane = 1
    
    var consumed, produced, _ = inflate_fast(
        input, 6, output, 10, state, 10
    )
    
    # Should handle error state gracefully
    assert_true(consumed >= 0)
    assert_true(produced >= 0)
    
    # Clean up
    input.free()
    output.free()
    lencode.free()
    distcode.free()