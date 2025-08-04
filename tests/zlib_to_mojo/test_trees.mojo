"""Unit tests for trees.mojo Huffman tree functionality."""

from testing import assert_equal, assert_not_equal, assert_true, assert_false

from zlib._src.zlib_to_mojo.trees import (
    CtData, StaticTreeDesc, TreeDesc, bi_reverse,
    init_static_dtree, init_dist_code, init_length_code,
    LENGTH_CODES, LITERALS, L_CODES, D_CODES, BL_CODES,
    MAX_BITS, MAX_BL_BITS, END_BLOCK, REP_3_6, REPZ_3_10, REPZ_11_138,
    DIST_CODE_LEN, BASE_LENGTH, BASE_DIST, EXTRA_LBITS, EXTRA_DBITS,
    EXTRA_BLBITS, BL_ORDER
)


def test_constants():
    """Test that tree constants are properly defined."""
    assert_equal(LENGTH_CODES, 29)
    assert_equal(LITERALS, 256)
    assert_equal(L_CODES, 286)  # 256 + 1 + 29
    assert_equal(D_CODES, 30)
    assert_equal(BL_CODES, 19)
    assert_equal(MAX_BITS, 15)
    assert_equal(MAX_BL_BITS, 7)
    assert_equal(END_BLOCK, 256)
    assert_equal(REP_3_6, 16)
    assert_equal(REPZ_3_10, 17)
    assert_equal(REPZ_11_138, 18)
    assert_equal(DIST_CODE_LEN, 512)


def test_ctdata_structure():
    """Test CtData structure creation and initialization."""
    # Test default initialization
    var ct1 = CtData()
    assert_equal(ct1.freq, 0)
    assert_equal(ct1.code, 0)
    assert_equal(ct1.dad, 0)
    assert_equal(ct1.len, 0)
    
    # Test custom initialization
    var ct2 = CtData(freq=10, code=5, dad=2, len=8)
    assert_equal(ct2.freq, 10)
    assert_equal(ct2.code, 5)
    assert_equal(ct2.dad, 2)
    assert_equal(ct2.len, 8)


def test_static_tree_desc():
    """Test StaticTreeDesc structure."""
    var desc = StaticTreeDesc(extra_base=1, elems=286, max_length=15)
    assert_equal(desc.extra_base, 1)
    assert_equal(desc.elems, 286)
    assert_equal(desc.max_length, 15)


def test_tree_desc():
    """Test TreeDesc structure."""
    var static_desc = StaticTreeDesc(elems=30, max_length=15)
    var desc = TreeDesc(max_code=25, stat_desc=static_desc)
    assert_equal(desc.max_code, 25)
    assert_equal(desc.stat_desc.elems, 30)
    assert_equal(desc.stat_desc.max_length, 15)


def test_bi_reverse():
    """Test bit reversal function."""
    # Test known bit reversal cases
    assert_equal(bi_reverse(0b1010, 4), 0b0101)  # 10 -> 5
    assert_equal(bi_reverse(0b1100, 4), 0b0011)  # 12 -> 3
    assert_equal(bi_reverse(0b1111, 4), 0b1111)  # 15 -> 15
    assert_equal(bi_reverse(0b0000, 4), 0b0000)  # 0 -> 0
    
    # Test single bit
    assert_equal(bi_reverse(0b1, 1), 0b1)
    assert_equal(bi_reverse(0b0, 1), 0b0)
    
    # Test longer sequences
    assert_equal(bi_reverse(0b10110, 5), 0b01101)  # 22 -> 13
    
    # Test edge case with 15 bits (max for Huffman codes)
    assert_equal(bi_reverse(0b100000000000001, 15), 0b100000000000001)  # palindromic


def test_extra_arrays():
    """Test extra bits arrays."""
    # Test EXTRA_LBITS array
    assert_equal(EXTRA_LBITS.size, LENGTH_CODES)
    assert_equal(EXTRA_LBITS[0], 0)  # First 8 length codes have no extra bits
    assert_equal(EXTRA_LBITS[8], 1)  # 9th code has 1 extra bit
    assert_equal(EXTRA_LBITS[12], 2) # 13th code has 2 extra bits
    assert_equal(EXTRA_LBITS[28], 0) # Last code has 0 extra bits
    
    # Test EXTRA_DBITS array
    assert_equal(EXTRA_DBITS.size, D_CODES)
    assert_equal(EXTRA_DBITS[0], 0)  # First 4 distance codes have no extra bits
    assert_equal(EXTRA_DBITS[4], 1)  # 5th code has 1 extra bit
    assert_equal(EXTRA_DBITS[6], 2)  # 7th code has 2 extra bits
    assert_equal(EXTRA_DBITS[29], 13) # Last code has 13 extra bits
    
    # Test EXTRA_BLBITS array
    assert_equal(EXTRA_BLBITS.size, BL_CODES)
    assert_equal(EXTRA_BLBITS[0], 0)  # Most bit length codes have no extra bits
    assert_equal(EXTRA_BLBITS[16], 2) # REP_3_6 has 2 extra bits
    assert_equal(EXTRA_BLBITS[17], 3) # REPZ_3_10 has 3 extra bits
    assert_equal(EXTRA_BLBITS[18], 7) # REPZ_11_138 has 7 extra bits


def test_bl_order():
    """Test bit length codes order array."""
    assert_equal(BL_ORDER.size, BL_CODES)
    # Test that it starts with the special codes
    assert_equal(BL_ORDER[0], 16)  # REP_3_6
    assert_equal(BL_ORDER[1], 17)  # REPZ_3_10
    assert_equal(BL_ORDER[2], 18)  # REPZ_11_138
    assert_equal(BL_ORDER[3], 0)   # Then regular codes in decreasing probability
    
    # Test that all values are valid bit length codes (0-18)
    for i in range(BL_CODES):
        assert_true(BL_ORDER[i] <= 18)


def test_base_arrays():
    """Test base value arrays."""
    # Test BASE_LENGTH array
    assert_equal(BASE_LENGTH.size, LENGTH_CODES)
    assert_equal(BASE_LENGTH[0], 0)   # Min match length base
    assert_equal(BASE_LENGTH[1], 1)   # Length code 1
    assert_equal(BASE_LENGTH[8], 8)   # Length code 8
    assert_equal(BASE_LENGTH[9], 10)  # Length code 9 (first with gap)
    assert_equal(BASE_LENGTH[28], 0)  # Last entry (special case)
    
    # Test BASE_DIST array
    assert_equal(BASE_DIST.size, D_CODES)
    assert_equal(BASE_DIST[0], 0)     # Distance code 0 (actually distance 1)
    assert_equal(BASE_DIST[1], 1)     # Distance code 1
    assert_equal(BASE_DIST[4], 4)     # Distance code 4
    assert_equal(BASE_DIST[5], 6)     # Distance code 5 (first with gap)
    assert_equal(BASE_DIST[29], 24576) # Last distance code


def test_init_static_dtree():
    """Test static distance tree initialization."""
    var dtree = init_static_dtree()
    assert_equal(dtree.size, D_CODES)
    
    # All distance codes should use 5 bits
    for i in range(D_CODES):
        assert_equal(dtree[i].len, 5)


def test_init_dist_code():
    """Test distance codes table initialization."""
    var dist_code = init_dist_code()
    assert_equal(dist_code.size, DIST_CODE_LEN)
    
    # Test some known values for distances 3-6 (first few entries)
    assert_equal(dist_code[0], 0)  # distance 3
    assert_equal(dist_code[1], 1)  # distance 4  
    assert_equal(dist_code[2], 2)  # distance 5
    assert_equal(dist_code[3], 3)  # distance 6
    
    # Test that codes are in valid range (0-29)
    for i in range(DIST_CODE_LEN):
        assert_true(dist_code[i] <= 29)


def test_init_length_code():
    """Test length codes table initialization."""
    var length_code = init_length_code()
    assert_equal(length_code.size, 256)
    
    # Test some known values
    assert_equal(length_code[0], 0)   # length 3 -> code 0
    assert_equal(length_code[1], 1)   # length 4 -> code 1
    assert_equal(length_code[7], 7)   # length 10 -> code 7
    
    # Test that codes are in valid range (0-28)
    for i in range(256):
        assert_true(length_code[i] <= 28)


def test_arrays_consistency():
    """Test consistency between related arrays."""
    # The number of extra bits should make sense with base values
    # For lengths: base[i] + (1 << extra[i]) should not exceed next base
    for i in range(LENGTH_CODES - 1):
        if BASE_LENGTH[i] > 0 and BASE_LENGTH[i + 1] > 0:  # Skip special cases
            max_with_extra = BASE_LENGTH[i] + (1 << EXTRA_LBITS[i]) - 1
            assert_true(max_with_extra < BASE_LENGTH[i + 1] or BASE_LENGTH[i + 1] == 0)
    
    # Similar test for distances (first few codes)
    for i in range(min(10, D_CODES - 1)):  # Test first 10 codes
        max_with_extra = BASE_DIST[i] + (1 << EXTRA_DBITS[i]) - 1
        if BASE_DIST[i + 1] > 0:
            assert_true(max_with_extra < BASE_DIST[i + 1])


def test_compile_time_generation():
    """Test that lookup tables are properly generated."""
    # Test that distance code table covers expected range
    var dist_code = init_dist_code()
    
    # First 256 entries should handle distances 3-258
    # All should have valid distance codes (0-29)
    for i in range(256):
        assert_true(dist_code[i] >= 0)
        assert_true(dist_code[i] < D_CODES)
    
    # Test that length code table handles lengths 3-258
    var length_code = init_length_code()
    
    # All should have valid length codes (0-28)
    for i in range(256):
        assert_true(length_code[i] >= 0)
        assert_true(length_code[i] < LENGTH_CODES)