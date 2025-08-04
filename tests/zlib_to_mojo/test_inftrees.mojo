"""Unit tests for inftrees.mojo Huffman tree building for decompression."""

from memory import UnsafePointer, memset_zero
from testing import assert_equal, assert_not_equal, assert_true, assert_false

from zlib._src.zlib_to_mojo.inftrees import (
    Code, CodeType, inflate_table,
    MAXBITS, ENOUGH_LENS, ENOUGH_DISTS, ENOUGH,
    LBASE, LEXT, DBASE, DEXT
)


def test_constants():
    """Test that inftrees constants are properly defined."""
    assert_equal(MAXBITS, 15)
    assert_equal(ENOUGH_LENS, 852)
    assert_equal(ENOUGH_DISTS, 592)
    assert_equal(ENOUGH, ENOUGH_LENS + ENOUGH_DISTS)


def test_code_structure():
    """Test Code structure creation and initialization."""
    # Test default initialization
    var code1 = Code()
    assert_equal(code1.op, 0)
    assert_equal(code1.bits, 0)
    assert_equal(code1.val, 0)
    
    # Test custom initialization
    var code2 = Code(op=64, bits=8, val=256)
    assert_equal(code2.op, 64)
    assert_equal(code2.bits, 8)
    assert_equal(code2.val, 256)


def test_code_type_constants():
    """Test CodeType constants."""
    assert_equal(CodeType.CODES, 0)
    assert_equal(CodeType.LENS, 1)
    assert_equal(CodeType.DISTS, 2)


def test_lookup_tables():
    """Test static lookup tables."""
    # Test LBASE array (length base values)
    assert_equal(LBASE.size, 31)
    assert_equal(LBASE[0], 3)    # Min match length
    assert_equal(LBASE[1], 4)    # Length code 1
    assert_equal(LBASE[8], 11)   # Length code 8
    assert_equal(LBASE[28], 258) # Max match length
    
    # Test LEXT array (length extra bits)
    assert_equal(LEXT.size, 31)
    assert_equal(LEXT[0], 16)    # All entries should be 16+ (shifted values)
    assert_equal(LEXT[8], 17)    # Extra bits + 16
    
    # Test DBASE array (distance base values)
    assert_equal(DBASE.size, 32)
    assert_equal(DBASE[0], 1)     # Min distance
    assert_equal(DBASE[1], 2)     # Distance code 1
    assert_equal(DBASE[4], 5)     # Distance code 4
    assert_equal(DBASE[29], 24577) # Max distance
    
    # Test DEXT array (distance extra bits)
    assert_equal(DEXT.size, 32)
    assert_equal(DEXT[0], 16)     # All entries should be 16+ (shifted values)
    assert_equal(DEXT[4], 17)     # Extra bits + 16


def test_inflate_table_no_symbols():
    """Test inflate_table with no symbols."""
    # Create empty lens array
    var lens = UnsafePointer[UInt16].alloc(1)
    lens[0] = 0  # No length for symbol 0
    
    # Create table space
    var table = UnsafePointer[Code].alloc(2)
    # Initialize table to zero
    for i in range(2):
        table[i] = Code()
    var work = UnsafePointer[UInt16].alloc(1)
    
    var bits: UInt = 1
    var result = inflate_table(CodeType.CODES, lens, 1, table, bits, work)
    
    # Should return 0 (success) but create invalid marker
    assert_equal(result, 0)
    assert_equal(table[0].op, 64)  # Invalid code marker
    assert_equal(table[0].bits, 1)
    assert_equal(table[1].op, 64)  # Invalid code marker
    
    # Clean up
    lens.free()
    table.free()
    work.free()


def test_inflate_table_single_symbol():
    """Test inflate_table with single symbol."""
    # Create lens array with one symbol of length 1
    var lens = UnsafePointer[UInt16].alloc(1)
    lens[0] = 1  # Symbol 0 has length 1
    
    # Create table space
    var table = UnsafePointer[Code].alloc(2)
    var work = UnsafePointer[UInt16].alloc(1)
    
    var bits: UInt = 1
    var result = inflate_table(CodeType.CODES, lens, 1, table, bits, work)
    # Single symbol creates incomplete set for CODES type, should return -1  
    assert_equal(result, -1)
    
    # Clean up
    lens.free()
    table.free()
    work.free()


def test_inflate_table_two_symbols():
    """Test inflate_table with two symbols."""
    # Create lens array with two symbols of length 1 each
    var lens = UnsafePointer[UInt16].alloc(2)
    lens[0] = 1  # Symbol 0 has length 1
    lens[1] = 1  # Symbol 1 has length 1
    
    # Create table space
    var table = UnsafePointer[Code].alloc(4)
    var work = UnsafePointer[UInt16].alloc(2)
    
    var bits: UInt = 1
    var result = inflate_table(CodeType.CODES, lens, 2, table, bits, work)
    # Should return 0 (success)
    assert_equal(result, 0)
    
    # Table should have entries for both symbols
    # Symbol assignment depends on Huffman algorithm, just check they're different
    var val0 = table[0].val
    var val1 = table[1].val
    assert_true((val0 == 0 and val1 == 1) or (val0 == 1 and val1 == 0))
    
    # Clean up
    lens.free()
    table.free()
    work.free()


def test_inflate_table_oversubscribed():
    """Test inflate_table with over-subscribed code lengths."""
    # Create lens array that would require more codes than possible
    var lens = UnsafePointer[UInt16].alloc(3)
    lens[0] = 1  # Symbol 0 has length 1 (uses 1/2 of code space)
    lens[1] = 1  # Symbol 1 has length 1 (uses 1/2 of code space)  
    lens[2] = 1  # Symbol 2 has length 1 (would need 1/2 more - over-subscribed!)
    
    # Create table space
    var table = UnsafePointer[Code].alloc(4)
    var work = UnsafePointer[UInt16].alloc(3)
    
    var bits: UInt = 2
    var result = inflate_table(CodeType.CODES, lens, 3, table, bits, work)
    
    # Should return -1 (over-subscribed)
    assert_equal(result, -1)
    
    # Clean up
    lens.free()
    table.free()
    work.free()


def test_inflate_table_incomplete_set():
    """Test inflate_table with incomplete code set."""
    # Create lens array with gap in code lengths
    var lens = UnsafePointer[UInt16].alloc(2)
    lens[0] = 2  # Symbol 0 has length 2 (uses 1/4 of code space)
    lens[1] = 0  # Symbol 1 has length 0 (not used)
    # This leaves 3/4 of code space unused - incomplete set
    
    # Create table space
    var table = UnsafePointer[Code].alloc(4)
    var work = UnsafePointer[UInt16].alloc(2)
    
    var bits: UInt = 2
    var result = inflate_table(CodeType.CODES, lens, 2, table, bits, work)
    
    # Should return -1 (incomplete set) for non-literal codes
    assert_equal(result, -1)
    
    # Clean up
    lens.free()
    table.free()
    work.free()


def test_inflate_table_length_codes():
    """Test inflate_table with length codes."""
    # Create a complete length code table (4 symbols of length 2 each)
    var lens = UnsafePointer[UInt16].alloc(4)
    lens[0] = 2  # Length code 257 (first length code)
    lens[1] = 2  # Length code 258
    lens[2] = 2  # Length code 259
    lens[3] = 2  # Length code 260
    
    # Create table space
    var table = UnsafePointer[Code].alloc(8)
    var work = UnsafePointer[UInt16].alloc(4)
    
    var bits: UInt = 2
    var result = inflate_table(CodeType.LENS, lens, 4, table, bits, work)
    
    # Should return 0 (success) - now we have a complete tree
    assert_equal(result, 0)
    
    # Check that table entries have appropriate structure
    for i in range(4):  # 2^2 = 4 table entries
        assert_true(table[i].bits <= 2)
    
    # Clean up
    lens.free()
    table.free()
    work.free()


def test_inflate_table_distance_codes():
    """Test inflate_table with distance codes."""
    # Create a simple distance code table
    var lens = UnsafePointer[UInt16].alloc(4)
    lens[0] = 2  # Distance code 0
    lens[1] = 2  # Distance code 1  
    lens[2] = 2  # Distance code 2
    lens[3] = 2  # Distance code 3
    
    # Create table space
    var table = UnsafePointer[Code].alloc(8)
    var work = UnsafePointer[UInt16].alloc(4)
    
    var bits: UInt = 2
    var result = inflate_table(CodeType.DISTS, lens, 4, table, bits, work)
    
    # Should return 0 (success)
    assert_equal(result, 0)
    
    # Check that table entries have appropriate structure
    for i in range(4):  # 2^2 = 4 table entries
        assert_true(table[i].bits <= 2)
    
    # Clean up
    lens.free()
    table.free()
    work.free()


def test_inflate_table_varying_lengths():
    """Test inflate_table with varying code lengths."""
    # Create a complete tree with varying lengths
    # Length 1: 1 symbol uses 1/2 space
    # Length 2: 1 symbol uses 1/4 space  
    # Length 3: 2 symbols use 2/8 = 1/4 space
    # Total: 1/2 + 1/4 + 1/4 = 1 (complete)
    var lens = UnsafePointer[UInt16].alloc(4)
    lens[0] = 1  # Symbol 0 has length 1 (uses 1/2 space)
    lens[1] = 2  # Symbol 1 has length 2 (uses 1/4 space)
    lens[2] = 3  # Symbol 2 has length 3 (uses 1/8 space)
    lens[3] = 3  # Symbol 3 has length 3 (uses 1/8 space)
    
    # Create table space (need enough for all combinations)
    var table = UnsafePointer[Code].alloc(8)
    var work = UnsafePointer[UInt16].alloc(4)
    
    var bits: UInt = 3
    var result = inflate_table(CodeType.CODES, lens, 4, table, bits, work)
    
    # Should return 0 (success) - now we have a complete tree
    assert_equal(result, 0)
    
    # Verify some basic properties
    var found_lengths = InlineArray[Bool, 4](False, False, False, False)
    for i in range(8):
        var code_bits = Int(table[i].bits)
        if code_bits >= 1 and code_bits <= 3:
            found_lengths[code_bits - 1] = True
    
    # Should have found codes of length 1, 2, and 3
    assert_true(found_lengths[0])  # Length 1
    assert_true(found_lengths[1])  # Length 2
    assert_true(found_lengths[2])  # Length 3
    
    # Clean up
    lens.free()
    table.free()
    work.free()


def test_inflate_table_memory_bounds():
    """Test that inflate_table respects memory bounds."""
    # Create a complete length table (exactly 8 symbols of length 3)
    var lens = UnsafePointer[UInt16].alloc(8)
    for i in range(8):
        lens[i] = UInt16(3)  # All symbols have length 3
    
    # Create appropriately sized table and work space
    var table = UnsafePointer[Code].alloc(16)  # 2^3 = 8 minimum, 16 for safety
    var work = UnsafePointer[UInt16].alloc(8)
    
    var bits: UInt = 3
    var result = inflate_table(CodeType.CODES, lens, 8, table, bits, work)
    
    # Should return 0 (success) - this is a complete tree (8 symbols use all 2^3 = 8 codes)
    assert_equal(result, 0)
    
    # Clean up
    lens.free()
    table.free()
    work.free()


def test_lookup_table_consistency():
    """Test consistency of LBASE/LEXT and DBASE/DEXT tables."""
    # Test that base + max_extra doesn't exceed next base value
    for i in range(min(20, LBASE.size - 1)):  # Test first 20 entries
        var base = LBASE[i]
        var extra_shifted = LEXT[i]
        if extra_shifted >= 16:  # Valid extra bits entry
            var extra = extra_shifted - 16
            var max_val = base + (1 << extra) - 1
            if i + 1 < LBASE.size and LBASE[i + 1] > 0:
                assert_true(max_val < LBASE[i + 1])
    
    # Similar test for distance codes
    for i in range(min(20, DBASE.size - 1)):  # Test first 20 entries
        var base = DBASE[i]
        var extra_shifted = DEXT[i]
        if extra_shifted >= 16:  # Valid extra bits entry
            var extra = extra_shifted - 16
            var max_val = base + (1 << extra) - 1
            if i + 1 < DBASE.size and DBASE[i + 1] > 0:
                assert_true(max_val < DBASE[i + 1])