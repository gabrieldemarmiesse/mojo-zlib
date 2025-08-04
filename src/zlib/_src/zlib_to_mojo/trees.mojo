"""Huffman tree generation and management for deflate compression.

Based on trees.c and trees.h from zlib 1.3.1.1.
This module provides the data structures and algorithms for building and
managing Huffman trees used in deflate compression.
"""

from memory import UnsafePointer

# Type aliases matching zlib C code
alias uch = UInt8
alias ush = UInt16

# Tree constants from deflate.h
alias LENGTH_CODES = 29  # number of length codes, not counting the special END_BLOCK code
alias LITERALS = 256     # number of literal bytes 0..255
alias L_CODES = LITERALS + 1 + LENGTH_CODES  # number of Literal or Length codes, including the END_BLOCK code
alias D_CODES = 30      # number of distance codes
alias BL_CODES = 19     # number of codes used to transfer the bit lengths
alias HEAP_SIZE = 2 * L_CODES + 1  # maximum heap size
alias MAX_BITS = 15     # All codes must not exceed MAX_BITS bits

# Tree-specific constants
alias MAX_BL_BITS = 7   # Bit length codes must not exceed MAX_BL_BITS bits
alias END_BLOCK = 256   # end of block literal code
alias REP_3_6 = 16     # repeat previous bit length 3-6 times (2 bits of repeat count)
alias REPZ_3_10 = 17   # repeat a zero length 3-10 times (3 bits of repeat count)
alias REPZ_11_138 = 18 # repeat a zero length 11-138 times (7 bits of repeat count)
alias DIST_CODE_LEN = 512  # see definition of array dist_code

# Frequency/code union structure
struct CtData(Copyable, Movable):
    """Data structure describing a single value and its code string."""
    var freq: ush  # frequency count or bit string
    var code: ush  # bit string (when used for codes)
    var dad: ush   # father node in Huffman tree
    var len: ush   # length of bit string

    fn __init__(out self, freq: ush = 0, code: ush = 0, dad: ush = 0, len: ush = 0):
        self.freq = freq
        self.code = code
        self.dad = dad
        self.len = len


# Static tree descriptor structure
struct StaticTreeDesc(Copyable, Movable):
    """Descriptor for static Huffman trees."""
    var static_tree: UnsafePointer[CtData]  # static tree or null
    var extra_bits: UnsafePointer[Int]      # extra bits for each code or null
    var extra_base: Int                     # base index for extra_bits
    var elems: Int                          # max number of elements in the tree
    var max_length: Int                     # max bit length for the codes

    fn __init__(
        out self,
        static_tree: UnsafePointer[CtData] = UnsafePointer[CtData](),
        extra_bits: UnsafePointer[Int] = UnsafePointer[Int](),
        extra_base: Int = 0,
        elems: Int = 0,
        max_length: Int = 0
    ):
        self.static_tree = static_tree
        self.extra_bits = extra_bits
        self.extra_base = extra_base
        self.elems = elems
        self.max_length = max_length


# Tree descriptor structure
struct TreeDesc(Copyable, Movable):
    """Descriptor for dynamic Huffman trees."""
    var dyn_tree: UnsafePointer[CtData]     # the dynamic tree
    var max_code: Int                       # largest code with non zero frequency
    var stat_desc: StaticTreeDesc           # the corresponding static tree

    fn __init__(
        out self,
        dyn_tree: UnsafePointer[CtData] = UnsafePointer[CtData](),
        max_code: Int = 0,
        stat_desc: StaticTreeDesc = StaticTreeDesc()
    ):
        self.dyn_tree = dyn_tree
        self.max_code = max_code
        self.stat_desc = stat_desc


# Extra bits for each length code
alias EXTRA_LBITS = InlineArray[Int, LENGTH_CODES](
    0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0
)

# Extra bits for each distance code
alias EXTRA_DBITS = InlineArray[Int, D_CODES](
    0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13
)

# Extra bits for each bit length code
alias EXTRA_BLBITS = InlineArray[Int, BL_CODES](
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 3, 7
)

# The lengths of the bit length codes are sent in order of decreasing probability
alias BL_ORDER = InlineArray[uch, BL_CODES](
    16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15
)

# Static literal tree (from trees.h)
alias STATIC_LTREE = InlineArray[CtData, L_CODES + 2](
    # This would be a massive array initialization - for now let's create a function to build it
    fill=CtData()
)

# Static distance tree (from trees.h) 
alias STATIC_DTREE = InlineArray[CtData, D_CODES](
    fill=CtData()
)

# Distance codes lookup table
alias DIST_CODE = InlineArray[uch, DIST_CODE_LEN](
    # 512 elements - will implement as function for compile-time generation
    fill=0
)

# Length codes lookup table  
alias LENGTH_CODE = InlineArray[uch, 256](  # MAX_MATCH - MIN_MATCH + 1 = 258 - 3 + 1 = 256
    fill=0
)

# Base values for length codes
alias BASE_LENGTH = InlineArray[Int, LENGTH_CODES](
    0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 14, 16, 20, 24, 28, 32, 40, 48, 56,
    64, 80, 96, 112, 128, 160, 192, 224, 0
)

# Base values for distance codes
alias BASE_DIST = InlineArray[Int, D_CODES](
    0, 1, 2, 3, 4, 6, 8, 12, 16, 24,
    32, 48, 64, 96, 128, 192, 256, 384, 512, 768,
    1024, 1536, 2048, 3072, 4096, 6144, 8192, 12288, 16384, 24576
)


fn bi_reverse(code: UInt, len: Int) -> UInt:
    """Reverse the first len bits of a code.
    
    Args:
        code: The code to reverse.
        len: Number of bits to reverse (1 <= len <= 15).
        
    Returns:
        The reversed code.
    """
    var res: UInt = 0
    var remaining_len = len
    var current_code = code
    
    while remaining_len > 0:
        res |= current_code & 1
        current_code >>= 1
        res <<= 1
        remaining_len -= 1
    
    return res >> 1


fn init_static_ltree() -> InlineArray[CtData, L_CODES + 2]:
    """Initialize the static literal tree at compile time.
    
    Returns:
        The initialized static literal tree.
    """
    # This would normally be done with the data from trees.h
    # For now, create a placeholder implementation
    var tree = InlineArray[CtData, L_CODES + 2](fill=CtData())
    
    # TODO: Fill in the actual static tree values from trees.h
    # This is a large table that would be better generated at compile time
    
    return tree


fn init_static_dtree() -> InlineArray[CtData, D_CODES]:
    """Initialize the static distance tree at compile time.
    
    Returns:
        The initialized static distance tree.
    """
    var tree = InlineArray[CtData, D_CODES](fill=CtData())
    
    # Static distance tree - all codes use 5 bits
    for i in range(D_CODES):
        tree[i] = CtData(0, 0, 0, 5)
    
    return tree


fn init_dist_code() -> InlineArray[uch, DIST_CODE_LEN]:
    """Initialize the distance codes lookup table at compile time.
    
    Returns:
        The initialized distance codes table.
    """
    var dist_code = InlineArray[uch, DIST_CODE_LEN](fill=0)
    
    # First 256 values correspond to distances 3..258
    for dist in range(256):
        if dist < 4:
            dist_code[dist] = uch(dist)
        elif dist < 8:
            dist_code[dist] = uch(4 + (dist - 4) // 2)
        elif dist < 16:
            dist_code[dist] = uch(6 + (dist - 8) // 4)
        elif dist < 32:
            dist_code[dist] = uch(8 + (dist - 16) // 8)
        elif dist < 64:
            dist_code[dist] = uch(10 + (dist - 32) // 16)
        elif dist < 128:
            dist_code[dist] = uch(12 + (dist - 64) // 32)
        else:
            dist_code[dist] = uch(14 + (dist - 128) // 64)
    
    # Last 256 values correspond to top 8 bits of 15 bit distances
    for i in range(256):
        dist_code[256 + i] = uch(_dist_code_high_bits(i))
    
    return dist_code


fn _dist_code_high_bits(high_byte: Int) -> Int:
    """Calculate distance code for high byte of 15-bit distance.
    
    Args:
        high_byte: The high 8 bits of a 15-bit distance.
        
    Returns:
        The corresponding distance code.
    """
    if high_byte < 2:
        return high_byte
    elif high_byte < 4:
        return 16 + (high_byte - 2)
    elif high_byte < 8:
        return 17 + (high_byte - 4) // 2
    elif high_byte < 16:
        return 18 + (high_byte - 8) // 4
    elif high_byte < 32:
        return 19 + (high_byte - 16) // 8
    elif high_byte < 64:
        return 20 + (high_byte - 32) // 16
    elif high_byte < 128:
        return 21 + (high_byte - 64) // 32
    else:
        return 22 + (high_byte - 128) // 64


fn init_length_code() -> InlineArray[uch, 256]:
    """Initialize the length codes lookup table at compile time.
    
    Returns:
        The initialized length codes table.
    """
    var length_code = InlineArray[uch, 256](fill=0)
    
    # Generate length codes for match lengths 3..258
    var code: Int = 0
    for len in range(3, 11):  # lengths 3-10: codes 0-7
        length_code[len - 3] = uch(code)
        code += 1
    
    # For lengths 11 and above, multiple lengths map to same code
    for len in range(11, 19):  # lengths 11-18: codes 8-9 (with extra bits)
        length_code[len - 3] = uch(8 + (len - 11) // 2)
    
    for len in range(19, 35):  # lengths 19-34: codes 10-13
        length_code[len - 3] = uch(10 + (len - 19) // 4)
    
    for len in range(35, 67):  # lengths 35-66: codes 14-17
        length_code[len - 3] = uch(14 + (len - 35) // 8)
    
    for len in range(67, 131):  # lengths 67-130: codes 18-21
        length_code[len - 3] = uch(18 + (len - 67) // 16)
    
    for len in range(131, 259):  # lengths 131-258: codes 22-28
        length_code[len - 3] = uch(22 + (len - 131) // 32)
    
    return length_code


# Static tree descriptor creation functions
fn get_static_l_desc() -> StaticTreeDesc:
    """Get the static literal tree descriptor."""
    return StaticTreeDesc(extra_base=LITERALS + 1, elems=L_CODES, max_length=MAX_BITS)

fn get_static_d_desc() -> StaticTreeDesc:
    """Get the static distance tree descriptor."""
    return StaticTreeDesc(extra_base=0, elems=D_CODES, max_length=MAX_BITS)

fn get_static_bl_desc() -> StaticTreeDesc:
    """Get the static bit length tree descriptor."""
    return StaticTreeDesc(extra_base=0, elems=BL_CODES, max_length=MAX_BL_BITS)