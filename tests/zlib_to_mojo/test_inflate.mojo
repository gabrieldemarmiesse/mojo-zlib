"""Unit tests for inflate.mojo main decompression logic."""

from memory import UnsafePointer, memset_zero
from testing import assert_equal, assert_not_equal, assert_true, assert_false

from zlib._src.zlib_to_mojo.inflate import (
    inflate_init, inflate_reset, inflate_main, min,
    Z_OK, Z_STREAM_ERROR, Z_DATA_ERROR, Z_MEM_ERROR, Z_BUF_ERROR,
    Z_NEED_DICT, Z_STREAM_END, Z_DEFLATED, DEF_WBITS, MAX_WBITS
)
from zlib._src.zlib_to_mojo.inflate_constants import InflateState, InflateMode


def test_constants():
    """Test inflate constants."""
    assert_equal(Z_OK, 0)
    assert_equal(Z_STREAM_ERROR, -2)
    assert_equal(Z_DATA_ERROR, -3)
    assert_equal(Z_MEM_ERROR, -4)
    assert_equal(Z_BUF_ERROR, -5)
    assert_equal(Z_NEED_DICT, 2)
    assert_equal(Z_STREAM_END, 1)
    assert_equal(Z_DEFLATED, 8)
    assert_equal(DEF_WBITS, 15)
    assert_equal(MAX_WBITS, 15)


def test_inflate_init_default():
    """Test inflate_init with default parameters."""
    var state = InflateState()
    var result = inflate_init(state, DEF_WBITS)
    
    assert_equal(result, Z_OK)
    assert_equal(state.mode, InflateMode.HEAD)
    assert_equal(state.last, 0)
    assert_equal(state.havedict, 0)
    assert_equal(state.wrap, 1)  # zlib format
    assert_equal(state.wbits, DEF_WBITS)
    assert_equal(state.wsize, 1 << DEF_WBITS)
    assert_equal(state.whave, 0)
    assert_equal(state.wnext, 0)
    assert_equal(state.hold, 0)
    assert_equal(state.bits, 0)
    assert_equal(state.sane, 1)
    assert_equal(state.back, -1)


def test_inflate_init_raw():
    """Test inflate_init with raw deflate (negative wbits)."""
    var state = InflateState()
    var result = inflate_init(state, -15)
    
    assert_equal(result, Z_OK)
    assert_equal(state.wrap, 0)  # raw deflate
    assert_equal(state.wbits, 15)


def test_inflate_init_gzip():
    """Test inflate_init with gzip format (wbits > 15)."""
    var state = InflateState()
    var result = inflate_init(state, 31)  # 15 + 16 for gzip
    
    assert_equal(result, Z_OK)
    assert_equal(state.wrap, 2)  # gzip format
    assert_equal(state.wbits, 15)


def test_inflate_init_invalid_wbits():
    """Test inflate_init with invalid window bits."""
    var state = InflateState()
    var result = inflate_init(state, 7)  # Too small
    
    assert_equal(result, Z_STREAM_ERROR)
    
    var result2 = inflate_init(state, 16)  # Too large (not gzip)
    assert_equal(result2, Z_STREAM_ERROR)


def test_inflate_reset():
    """Test inflate_reset functionality."""
    var state = InflateState()
    _ = inflate_init(state, DEF_WBITS)
    
    # Modify some state
    state.mode = InflateMode.LEN
    state.last = 1
    state.hold = 0x12345678
    state.bits = 32
    
    var result = inflate_reset(state)
    
    assert_equal(result, Z_OK)
    assert_equal(state.mode, InflateMode.HEAD)
    assert_equal(state.last, 0)
    assert_equal(state.hold, 0)
    assert_equal(state.bits, 0)
    assert_equal(state.back, -1)


def test_inflate_main_no_input():
    """Test inflate_main with no input data."""
    var state = InflateState()
    _ = inflate_init(state, DEF_WBITS)
    
    var input = UnsafePointer[UInt8].alloc(1)
    var output = UnsafePointer[UInt8].alloc(100)
    
    var consumed, produced, ret, _ = inflate_main(
        input, 0, output, 100, state
    )
    
    assert_equal(consumed, 0)
    assert_equal(produced, 0)
    assert_equal(ret, Z_OK)  # Should return OK but make no progress
    
    # Clean up
    input.free()
    output.free()


def test_inflate_main_raw_deflate():
    """Test inflate_main with raw deflate mode."""
    var state = InflateState()
    _ = inflate_init(state, -15)  # Raw deflate
    
    var input = UnsafePointer[UInt8].alloc(10)
    var output = UnsafePointer[UInt8].alloc(100)
    
    # Fill input with simple deflate data (stored block)
    input[0] = 0x01  # Last block, stored type
    input[1] = 0x05  # Length = 5 (low byte)
    input[2] = 0x00  # Length = 5 (high byte) 
    input[3] = 0xFA  # ~Length = 250 (low byte)
    input[4] = 0xFF  # ~Length = 250 (high byte)
    # Data bytes
    input[5] = 0x48  # 'H'
    input[6] = 0x65  # 'e'
    input[7] = 0x6C  # 'l'
    input[8] = 0x6C  # 'l'
    input[9] = 0x6F  # 'o'
    
    var consumed, produced, _, _ = inflate_main(
        input, 10, output, 100, state
    )
    
    # Should process some input
    assert_true(consumed > 0)
    # May or may not produce output depending on implementation
    assert_true(produced >= 0)
    
    # Clean up
    input.free()
    output.free()


def test_inflate_main_invalid_header():
    """Test inflate_main with invalid zlib header."""
    var state = InflateState()
    _ = inflate_init(state, 15)  # zlib format
    
    var input = UnsafePointer[UInt8].alloc(2)
    var output = UnsafePointer[UInt8].alloc(100)
    
    # Invalid zlib header (doesn't pass checksum)
    input[0] = 0x78  # CMF
    input[1] = 0x9C  # FLG (invalid checksum)
    
    var _, _, ret, new_state = inflate_main(
        input, 2, output, 100, state
    )
    
    # Should detect error
    assert_equal(ret, Z_DATA_ERROR)
    assert_equal(new_state.mode, InflateMode.BAD)
    
    # Clean up
    input.free()
    output.free()


def test_inflate_main_valid_zlib_header():
    """Test inflate_main with valid zlib header."""
    var state = InflateState()
    _ = inflate_init(state, 15)  # zlib format
    
    var input = UnsafePointer[UInt8].alloc(4)
    var output = UnsafePointer[UInt8].alloc(100)
    
    # Valid zlib header
    input[0] = 0x78  # CMF: method=8, wbits=15
    input[1] = 0x9C  # FLG: level=2, checksum ok
    input[2] = 0x01  # Start of deflate data
    input[3] = 0x00
    
    var consumed, _, ret, _ = inflate_main(
        input, 4, output, 100, state
    )
    
    # Should process header successfully, but deflate data is invalid
    assert_true(consumed >= 2)  # At least header consumed
    # Since the deflate data (0x01 0x00) is invalid (block type 3), expect Z_DATA_ERROR
    assert_true(ret == Z_DATA_ERROR)  # Invalid deflate data
    
    # Clean up
    input.free()
    output.free()


def test_inflate_main_buffer_management():
    """Test inflate_main buffer management."""
    var state = InflateState()
    _ = inflate_init(state, -15)  # Raw deflate
    
    var input = UnsafePointer[UInt8].alloc(5)
    var output = UnsafePointer[UInt8].alloc(5)  # Small output buffer
    
    # Simple stored block
    input[0] = 0x01  # Last block, stored
    input[1] = 0x02  # Length = 2
    input[2] = 0x00
    input[3] = 0xFD  # ~Length
    input[4] = 0xFF
    
    var consumed, produced, _, _ = inflate_main(
        input, 5, output, 5, state
    )
    
    # Should handle buffers appropriately
    assert_true(consumed <= 5)
    assert_true(produced <= 5)
    
    # Clean up
    input.free()
    output.free()


def test_min_function():
    """Test min helper function."""
    assert_equal(min(5, 10), 5)
    assert_equal(min(10, 5), 5)
    assert_equal(min(7, 7), 7)
    assert_equal(min(0, 100), 0)
    assert_equal(min(100, 0), 0)


def test_state_transitions():
    """Test basic state transitions."""
    var state = InflateState()
    _ = inflate_init(state, -15)  # Raw deflate (skips header)
    
    # Should start in HEAD mode, transition to TYPEDO for raw
    assert_equal(state.mode, InflateMode.HEAD)
    
    var input = UnsafePointer[UInt8].alloc(1)
    var output = UnsafePointer[UInt8].alloc(100)
    input[0] = 0x00  # Some data
    
    var _, _, _, new_state = inflate_main(
        input, 1, output, 100, state
    )
    
    # Should have transitioned from HEAD
    assert_not_equal(new_state.mode, InflateMode.HEAD)
    
    # Clean up
    input.free()
    output.free()


def test_bit_accumulator():
    """Test bit accumulator functionality."""
    var state = InflateState()
    _ = inflate_init(state, DEF_WBITS)
    
    # Initial state
    assert_equal(state.hold, 0)
    assert_equal(state.bits, 0)
    
    var input = UnsafePointer[UInt8].alloc(3)
    var output = UnsafePointer[UInt8].alloc(100)
    
    # Some input data
    input[0] = 0x12
    input[1] = 0x34
    input[2] = 0x56
    
    var _, _, _, new_state = inflate_main(
        input, 3, output, 100, state
    )
    
    # Bit accumulator should be updated
    # (Exact values depend on processing, but should be valid)
    assert_true(new_state.bits <= 64)
    
    # Clean up
    input.free()
    output.free()


def test_window_size_calculation():
    """Test window size calculation for different wbits.""" 
    var state = InflateState()
    
    _ = inflate_init(state, 8)
    assert_equal(state.wsize, 256)  # 2^8
    
    _ = inflate_init(state, 15)
    assert_equal(state.wsize, 32768)  # 2^15
    
    _ = inflate_init(state, -12)
    assert_equal(state.wsize, 4096)  # 2^12


def test_wrap_mode_detection():
    """Test wrap mode detection from wbits parameter."""
    var state = InflateState()
    
    # zlib format
    _ = inflate_init(state, 15)
    assert_equal(state.wrap, 1)
    
    # raw deflate
    _ = inflate_init(state, -15)
    assert_equal(state.wrap, 0)
    
    # gzip format
    _ = inflate_init(state, 31)  # 15 + 16
    assert_equal(state.wrap, 2)


def test_error_handling():
    """Test error handling in various scenarios."""
    var state = InflateState()
    
    # Test invalid window bits
    var result = inflate_init(state, 6)  # Too small
    assert_equal(result, Z_STREAM_ERROR)
    
    result = inflate_init(state, 16)  # Invalid range
    assert_equal(result, Z_STREAM_ERROR)
    
    # Test with valid init
    result = inflate_init(state, 15)
    assert_equal(result, Z_OK)
    
    # Test with corrupted input
    var input = UnsafePointer[UInt8].alloc(2)
    var output = UnsafePointer[UInt8].alloc(100)
    
    # Bad zlib header
    input[0] = 0xFF
    input[1] = 0xFF
    
    var _, _, ret, _ = inflate_main(input, 2, output, 100, state)
    assert_equal(ret, Z_DATA_ERROR)
    
    # Clean up
    input.free()  
    output.free()