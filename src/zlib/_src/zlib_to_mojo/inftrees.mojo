# Huffman tree building for inflate decompression
# Based on inftrees.h and inftrees.c from zlib 1.3.1.1

from memory import UnsafePointer
from sys import ffi


# Maximum number of bits in a Huffman code
alias MAXBITS = 15

# Maximum table sizes from C constants
alias ENOUGH_LENS = 852
alias ENOUGH_DISTS = 592
alias ENOUGH = ENOUGH_LENS + ENOUGH_DISTS

# Static lookup tables for length and distance codes
alias LBASE = InlineArray[UInt16, 31](
    3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
    35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258, 0, 0
)

alias LEXT = InlineArray[UInt16, 31](
    16, 16, 16, 16, 16, 16, 16, 16, 17, 17, 17, 17, 18, 18, 18, 18,
    19, 19, 19, 19, 20, 20, 20, 20, 21, 21, 21, 21, 16, 73, 200
)

alias DBASE = InlineArray[UInt16, 32](
    1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
    257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145,
    8193, 12289, 16385, 24577, 0, 0
)

alias DEXT = InlineArray[UInt16, 32](
    16, 16, 16, 16, 17, 17, 18, 18, 19, 19, 20, 20, 21, 21, 22, 22,
    23, 23, 24, 24, 25, 25, 26, 26, 27, 27, 28, 28, 29, 29, 64, 64
)



struct Code(Copyable, Movable):
    """Structure for decoding tables.
    
    Each entry provides either the information needed to do the operation 
    requested by the code that indexed that table entry, or it provides a 
    pointer to another table that indexes more bits of the code.
    """
    var op: UInt8      # operation, extra bits, table bits
    var bits: UInt8    # bits in this part of the code  
    var val: UInt16    # offset in table or code value

    fn __init__(out self, op: UInt8 = 0, bits: UInt8 = 0, val: UInt16 = 0):
        self.op = op
        self.bits = bits
        self.val = val


struct CodeType:
    """Type of code to build for inflate_table."""
    alias CODES = 0
    alias LENS = 1
    alias DISTS = 2


fn inflate_table[O: MutableOrigin](
    code_type: Int,
    lens: UnsafePointer[UInt16],
    codes: UInt,
    var table: UnsafePointer[Code, mut = O.mut, origin=O],
    mut bits: UInt,
    work: UnsafePointer[UInt16]
) -> Int32:
    """Build a set of tables to decode the provided canonical Huffman code.
    
    Args:
        code_type: Type of code to be generated (CODES, LENS, or DISTS).
        lens: Code lengths array [0..codes-1].
        codes: Number of codes.
        table: Pointer to table space, updated to point to next available entry.
        bits: Requested root table index bits, updated to actual root table bits.
        work: Work array of at least lens shorts.
        
    Returns:
        0 on success, -1 for invalid code, +1 if ENOUGH isn't enough.
    """
    # Local variables matching C implementation
    var len: UInt             # a code's length in bits
    var sym: UInt             # index of code symbols  
    var min: UInt             # minimum code length
    var max: UInt             # maximum code length
    var root: UInt            # number of index bits for root table
    var curr: UInt            # number of index bits for current table
    var drop: UInt            # code bits to drop for sub-table
    var left: Int32           # number of prefix codes available
    var used: UInt            # code entries in table used  
    var huff: UInt            # Huffman code
    var incr: UInt            # for incrementing code, index
    var fill: UInt            # index for replicating entries
    var low: UInt             # low bits for current root entry
    var mask: UInt            # mask for low root bits
    var here = Code()         # table entry for duplication
    var next: UnsafePointer[Code]  # next available space in table
    var base: UnsafePointer[UInt16]  # base value table to use
    var extra: UnsafePointer[UInt16] # extra bits table to use
    var match_val: UInt
    var count = InlineArray[UInt16, MAXBITS + 1](fill=0)  # number of codes of each length
    var offs = InlineArray[UInt16, MAXBITS + 1](fill=0)   # offsets in table for each length

    # Accumulate lengths for codes (assumes lens[] all in 0..MAXBITS)
    for len_val in range(MAXBITS + 1):
        count[len_val] = 0
    for sym_val in range(codes):
        count[Int(lens[sym_val])] += 1

    # Bound code lengths, force root to be within code lengths
    root = bits
    max = MAXBITS
    while max >= 1:
        if count[Int(max)] != 0:
            break
        max -= 1

    if root > max:
        root = max
    
    if max == 0:  # no symbols to code at all
        here.op = 64  # invalid code marker
        here.bits = 1
        here.val = 0
        table[0] = here  # make a table to force an error
        table[1] = here
        _ = table + 2
        bits = 1
        return 0  # no symbols, but wait for decoding to report error

    min = 1
    while min < max:
        if count[Int(min)] != 0:
            break
        min += 1
    
    if root < min:
        root = min

    # Check for an over-subscribed or incomplete set of lengths
    left = 1
    for len_val in range(1, MAXBITS + 1):
        left <<= 1
        left -= Int32(count[len_val])
        if left < 0:
            return -1  # over-subscribed

    if left > 0 and (code_type == 0 or max != 1):
        return -1  # incomplete set

    # Generate offsets into symbol table for each length for sorting
    offs[1] = 0
    for len_val in range(1, MAXBITS):
        offs[len_val + 1] = offs[len_val] + count[len_val]

    # Sort symbols by length, by symbol order within each length
    for sym_val in range(codes):
        if lens[sym_val] != 0:
            work[offs[Int(lens[sym_val])]] = UInt16(sym_val)
            offs[Int(lens[sym_val])] += 1

    # Set up for code type
    if code_type == 0:
        base = work  # dummy value--not used
        extra = work  # dummy value--not used
        match_val = 20
    elif code_type == 1:
        base = UnsafePointer(to=LBASE[0])
        extra = UnsafePointer(to=LEXT[0])
        match_val = 257
    else:  # DISTS
        base = UnsafePointer(to=DBASE[0])
        extra = UnsafePointer(to=DEXT[0])
        match_val = 0

    # Initialize state for loop
    huff = 0                    # starting code
    sym = 0                     # starting code symbol
    len = min                   # starting code length
    next = table                # current table to fill in
    curr = root                 # current table index bits
    drop = 0                    # current bits to drop from code for index
    low = UInt.MAX             # trigger new sub-table when len > root
    used = 1 << root            # use root table entries
    mask = used - 1             # mask for comparing low

    # Check available table space
    if (code_type == 1 and used > ENOUGH_LENS) or (code_type == 2 and used > ENOUGH_DISTS):
        return 1

    # Process all codes and make table entries
    while True:
        # Create table entry
        here.bits = UInt8(len - drop)
        if UInt(work[sym]) + 1 < match_val:
            here.op = 0
            here.val = work[sym]
        elif UInt(work[sym]) >= match_val:
            here.op = UInt8(extra[UInt(work[sym]) - match_val])
            here.val = base[UInt(work[sym]) - match_val]
        else:
            here.op = 32 + 64  # end of block
            here.val = 0

        # Replicate for those indices with low len bits equal to huff
        incr = 1 << (len - drop)
        fill = 1 << curr
        min = fill  # save offset to next table
        
        while fill != 0:
            fill -= incr
            next[(huff >> drop) + fill] = here

        # Backwards increment the len-bit code huff
        incr = 1 << (len - 1)
        while (huff & incr) != 0:
            incr >>= 1
        
        if incr != 0:
            huff &= incr - 1
            huff += incr
        else:
            huff = 0

        # Go to next symbol, update count, len
        sym += 1
        count[Int(len)] -= 1
        if count[Int(len)] == 0:
            if len == max:
                break
            len = UInt(lens[work[sym]])

        # Create new sub-table if needed
        if len > root and (huff & mask) != low:
            # If first time, transition to sub-tables
            if drop == 0:
                drop = root

            # Increment past last table
            next += min  # here min is 1 << curr

            # Determine length of next table
            curr = len - drop
            left = Int32(1 << curr)
            while curr + drop < max:
                left -= Int32(count[Int(curr + drop)])
                if left <= 0:
                    break
                curr += 1
                left <<= 1

            # Check for enough space
            used += 1 << curr
            if (code_type == 1 and used > ENOUGH_LENS) or (code_type == 2 and used > ENOUGH_DISTS):
                return 1

            # Point entry in root table to sub-table
            low = huff & mask
            table[low].op = UInt8(curr)
            table[low].bits = UInt8(root)
            table[low].val = UInt16(Int(next) - Int(table))

    # Fill in remaining table entry if code is incomplete
    if huff != 0:
        here.op = 64  # invalid code marker
        here.bits = UInt8(len - drop)
        here.val = 0
        next[huff] = here

    # Set return parameters
    table += used
    bits = root
    return 0