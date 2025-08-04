"""Unit tests for inflate_constants.mojo decompression state and constants."""

from testing import assert_equal, assert_not_equal, assert_true, assert_false

from zlib._src.zlib_to_mojo.inflate_constants import (
    InflateMode, InflateState, init_fixed_tables,
    needbits, bits, dropbits, bytebits,
    LENFIX_SIZE, DISTFIX_SIZE, MAX_WBITS, DEF_WBITS,
    INFLATE_STRICT, INFLATE_ALLOW
)
from zlib._src.zlib_to_mojo.inftrees import Code


def test_inflate_mode_constants():
    """Test that inflate mode constants are properly defined."""
    # Test basic mode values
    assert_equal(InflateMode.HEAD, 16180)
    assert_equal(InflateMode.FLAGS, 16181)
    assert_equal(InflateMode.TIME, 16182)
    assert_equal(InflateMode.OS, 16183)
    
    # Test block processing modes
    assert_equal(InflateMode.TYPE, 16191)
    assert_equal(InflateMode.TYPEDO, 16192)
    assert_equal(InflateMode.STORED, 16193)
    assert_equal(InflateMode.TABLE, 16196)
    
    # Test code decoding modes
    assert_equal(InflateMode.LEN_, 16199)
    assert_equal(InflateMode.LEN, 16200)
    assert_equal(InflateMode.LENEXT, 16201)
    assert_equal(InflateMode.DIST, 16202)
    assert_equal(InflateMode.DISTEXT, 16203)
    assert_equal(InflateMode.MATCH, 16204)
    assert_equal(InflateMode.LIT, 16205)
    
    # Test completion and error modes
    assert_equal(InflateMode.CHECK, 16206)
    assert_equal(InflateMode.LENGTH, 16207)
    assert_equal(InflateMode.DONE, 16208)
    assert_equal(InflateMode.BAD, 16209)
    assert_equal(InflateMode.MEM, 16210)
    assert_equal(InflateMode.SYNC, 16211)


def test_inflate_state_initialization():
    """Test InflateState structure initialization."""
    var state = InflateState()
    
    # Test default values
    assert_equal(state.mode, InflateMode.HEAD)
    assert_equal(state.last, 0)
    assert_equal(state.wrap, 0)
    assert_equal(state.havedict, 0)
    assert_equal(state.flags, 0)
    assert_equal(state.dmax, 0)
    assert_equal(state.check, 0)
    assert_equal(state.total, 0)
    
    # Test window state
    assert_equal(state.wbits, 0)
    assert_equal(state.wsize, 0)
    assert_equal(state.whave, 0)
    assert_equal(state.wnext, 0)
    
    # Test bit accumulator
    assert_equal(state.hold, 0)
    assert_equal(state.bits, 0)
    
    # Test copy state
    assert_equal(state.length, 0)
    assert_equal(state.offset, 0)
    assert_equal(state.extra, 0)
    
    # Test decode table state
    assert_equal(state.lenbits, 0)
    assert_equal(state.distbits, 0)
    
    # Test dynamic table building state
    assert_equal(state.ncode, 0)
    assert_equal(state.nlen, 0)
    assert_equal(state.ndist, 0)
    assert_equal(state.have, 0)
    
    # Test other state
    assert_equal(state.sane, 1)
    assert_equal(state.back, -1)
    assert_equal(state.was, 0)


def test_fixed_table_constants():
    """Test fixed table size constants."""
    assert_equal(LENFIX_SIZE, 512)
    assert_equal(DISTFIX_SIZE, 32)


def test_init_fixed_tables():
    """Test fixed table initialization."""
    var lenfix, distfix = init_fixed_tables()
    
    # Test table sizes
    assert_equal(len(lenfix), LENFIX_SIZE)
    assert_equal(len(distfix), DISTFIX_SIZE)
    
    # Test literal codes (0-143) have 8 bits
    for i in range(144):
        assert_equal(lenfix[i].bits, 8)
        assert_equal(lenfix[i].val, i)
        assert_equal(lenfix[i].op, 0)  # literal
    
    # Test literal codes (144-255) have 9 bits  
    for i in range(144, 256):
        assert_equal(lenfix[i].bits, 9)
        assert_equal(lenfix[i].val, i)
        assert_equal(lenfix[i].op, 0)  # literal
    
    # Test length codes (256-279) have 7 bits
    for i in range(256, 280):
        assert_equal(lenfix[i].bits, 7)
        assert_equal(lenfix[i].val, i)
        assert_equal(lenfix[i].op, 0)  # length code
    
    # Test length codes (280-287) have 8 bits
    for i in range(280, 288):
        assert_equal(lenfix[i].bits, 8)
        assert_equal(lenfix[i].val, i)
        assert_equal(lenfix[i].op, 0)  # length code
    
    # Test remaining entries are invalid
    for i in range(288, LENFIX_SIZE):
        assert_equal(lenfix[i].op, 64)  # invalid code marker
        assert_equal(lenfix[i].bits, 0)
        assert_equal(lenfix[i].val, 0)
    
    # Test all distance codes use 5 bits
    for i in range(DISTFIX_SIZE):
        assert_equal(distfix[i].bits, 5)
        assert_equal(distfix[i].val, i)
        assert_equal(distfix[i].op, 0)  # distance code


def test_bit_manipulation_functions():
    """Test bit manipulation helper functions."""
    var state = InflateState()
    
    # Test needbits function
    state.bits = 5
    assert_true(needbits(state, 8))   # Need more bits
    assert_false(needbits(state, 3))  # Have enough bits
    assert_false(needbits(state, 5))  # Exactly enough bits
    
    # Test bits extraction
    state.hold = 0b11010110  # Binary: 11010110
    state.bits = 8
    
    assert_equal(bits(state, 3), 0b110)      # Extract 3 lowest bits: 110
    assert_equal(bits(state, 5), 0b10110)    # Extract 5 lowest bits: 10110
    assert_equal(bits(state, 8), 0b11010110) # Extract all 8 bits
    
    # Test dropbits function
    dropbits(state, 3)
    assert_equal(state.hold, 0b11010)  # Should shift right by 3
    assert_equal(state.bits, 5)        # Should decrease by 3
    
    # Test bytebits function (round down to byte boundary)
    state.hold = 0b11010110
    state.bits = 11  # 1 byte + 3 bits
    bytebits(state)
    assert_equal(state.bits, 8)  # Should round down to 8 bits (1 byte)
    
    state.bits = 13  # 1 byte + 5 bits  
    bytebits(state)
    assert_equal(state.bits, 8)  # Should round down to 8 bits (1 byte)


def test_window_size_constants():
    """Test window size constants."""
    assert_equal(MAX_WBITS, 15)
    assert_equal(DEF_WBITS, MAX_WBITS)
    
    # Test that max window size makes sense (2^15 = 32K)
    assert_equal(1 << MAX_WBITS, 32768)


def test_inflate_constants():
    """Test other inflate constants."""
    assert_equal(INFLATE_STRICT, 1)
    assert_equal(INFLATE_ALLOW, 0)


def test_state_mode_transitions():
    """Test that state mode can be changed."""
    var state = InflateState()
    
    # Start in HEAD mode
    assert_equal(state.mode, InflateMode.HEAD)
    
    # Change to different modes
    state.mode = InflateMode.FLAGS  
    assert_equal(state.mode, InflateMode.FLAGS)
    
    state.mode = InflateMode.TYPE
    assert_equal(state.mode, InflateMode.TYPE)
    
    state.mode = InflateMode.DONE
    assert_equal(state.mode, InflateMode.DONE)
    
    state.mode = InflateMode.BAD
    assert_equal(state.mode, InflateMode.BAD)


def test_bit_accumulator_operations():
    """Test bit accumulator state management."""
    var state = InflateState()
    
    # Test setting hold and bits
    state.hold = 0x12345678
    state.bits = 32
    
    assert_equal(state.hold, 0x12345678)
    assert_equal(state.bits, 32)
    
    # Test that bits() doesn't modify state
    var extracted = bits(state, 8)
    assert_equal(extracted, 0x78)  # Lower 8 bits
    assert_equal(state.hold, 0x12345678)  # Unchanged
    assert_equal(state.bits, 32)          # Unchanged
    
    # Test that dropbits() modifies state
    dropbits(state, 8)
    assert_equal(state.hold, 0x123456)  # Shifted right by 8
    assert_equal(state.bits, 24)        # Decreased by 8


def test_window_state_management():
    """Test sliding window state variables."""
    var state = InflateState()
    
    # Test setting window parameters
    state.wbits = 15
    state.wsize = 32768  # 2^15
    state.whave = 1024
    state.wnext = 512
    
    assert_equal(state.wbits, 15)
    assert_equal(state.wsize, 32768)
    assert_equal(state.whave, 1024)
    assert_equal(state.wnext, 512)


def test_decode_table_state():
    """Test decode table state management."""
    var state = InflateState()
    
    # Test setting decode table parameters
    state.lenbits = 9
    state.distbits = 5
    
    assert_equal(state.lenbits, 9)
    assert_equal(state.distbits, 5)


def test_dynamic_table_building_state():
    """Test dynamic table building state variables."""
    var state = InflateState()
    
    # Test setting dynamic table parameters
    state.ncode = 19
    state.nlen = 257
    state.ndist = 32
    state.have = 288
    
    assert_equal(state.ncode, 19)
    assert_equal(state.nlen, 257)
    assert_equal(state.ndist, 32)
    assert_equal(state.have, 288)