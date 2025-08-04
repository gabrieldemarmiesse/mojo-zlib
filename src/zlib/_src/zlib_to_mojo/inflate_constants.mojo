"""Decompression state and constants for inflate.

Based on inflate.h and inflate.c from zlib 1.3.1.1.
This module provides the state machine constants and data structures
needed for inflate decompression.
"""

from memory import UnsafePointer
from .inftrees import Code
from ..constants import USE_ZLIB

# Inflate modes between inflate() calls
struct InflateMode:
    """Possible inflate modes between inflate() calls."""
    alias HEAD = 16180     # i: waiting for magic header
    alias FLAGS = 16181    # i: waiting for method and flags (gzip)
    alias TIME = 16182     # i: waiting for modification time (gzip)
    alias OS = 16183       # i: waiting for extra flags and operating system (gzip)
    alias EXLEN = 16184    # i: waiting for extra length (gzip)
    alias EXTRA = 16185    # i: waiting for extra bytes (gzip)
    alias NAME = 16186     # i: waiting for end of file name (gzip)
    alias COMMENT = 16187  # i: waiting for end of comment (gzip)
    alias HCRC = 16188     # i: waiting for header crc (gzip)
    alias DICTID = 16189   # i: waiting for dictionary check value
    alias DICT = 16190     # waiting for inflateSetDictionary() call
    alias TYPE = 16191     # i: waiting for type bits, including last-flag bit
    alias TYPEDO = 16192   # i: same, but skip check to exit inflate on new block
    alias STORED = 16193   # i: waiting for stored size (length and complement)
    alias COPY_ = 16194    # i/o: same as COPY below, but only first time in
    alias COPY = 16195     # i/o: waiting for input or output to copy stored block
    alias TABLE = 16196    # i: waiting for dynamic block table lengths
    alias LENLENS = 16197  # i: waiting for code length code lengths
    alias CODELENS = 16198 # i: waiting for length/lit and distance code lengths
    alias LEN_ = 16199     # i: same as LEN below, but only first time in
    alias LEN = 16200      # i: waiting for length/lit/eob code
    alias LENEXT = 16201   # i: waiting for length extra bits
    alias DIST = 16202     # i: waiting for distance code
    alias DISTEXT = 16203  # i: waiting for distance extra bits
    alias MATCH = 16204    # o: waiting for output space to copy string
    alias LIT = 16205      # o: waiting for output space to write literal
    alias CHECK = 16206    # i: waiting for 32-bit check value
    alias LENGTH = 16207   # i: waiting for 32-bit length (gzip)
    alias DONE = 16208     # finished check, done -- remain here until reset
    alias BAD = 16209      # got a data error -- remain here until reset
    alias MEM = 16210      # got an inflate() memory error -- remain here until reset
    alias SYNC = 16211     # looking for synchronization bytes to restart inflate()


# Inflate state structure 
struct InflateState(Copyable, Movable):
    """State maintained between inflate() calls.
    
    Approximately 7K bytes, not including the allocated sliding window,
    which is up to 32K bytes.
    """
    # Stream reference (would be UnsafePointer[ZStream] in full implementation)
    var strm: UnsafePointer[UInt8]  # pointer back to this zlib stream
    var mode: Int                   # current inflate mode (InflateMode value)
    var last: Int                   # true if processing last block
    var wrap: Int                   # bit 0 true for zlib, bit 1 true for gzip,
                                    # bit 2 true to validate check value
    var havedict: Int               # true if dictionary provided
    var flags: Int                  # gzip header method and flags, 0 if zlib,
                                    # or -1 if raw or no header yet
    var dmax: UInt                  # zlib header max distance (INFLATE_STRICT)
    var check: UInt64               # protected copy of check value
    var total: UInt64               # protected copy of output count
    
    # Sliding window
    var wbits: UInt                 # log base 2 of requested window size
    var wsize: UInt                 # window size or zero if not using window
    var whave: UInt                 # valid bytes in the window
    var wnext: UInt                 # window write index
    var window: UnsafePointer[UInt8] # allocated sliding window, if needed
    
    # Bit accumulator
    var hold: UInt64                # input bit accumulator
    var bits: UInt                  # number of bits in hold
    
    # For string and stored block copying
    var length: UInt                # literal or length of data to copy
    var offset: UInt                # distance back to copy string from
    
    # For table and code decoding
    var extra: UInt                 # extra bits needed
    
    # Fixed and dynamic code tables
    var lencode: UnsafePointer[Code] # starting table for length/literal codes
    var distcode: UnsafePointer[Code] # starting table for distance codes
    var lenbits: UInt               # index bits for lencode
    var distbits: UInt              # index bits for distcode
    
    # Dynamic table building
    var ncode: UInt                 # number of code length code lengths
    var nlen: UInt                  # number of length code lengths
    var ndist: UInt                 # number of distance code lengths
    var have: UInt                  # number of code lengths in lens[]
    var next: UnsafePointer[Code]   # next available space in codes[]
    var lens: UnsafePointer[UInt16] # temporary storage for code lengths (320)
    var work: UnsafePointer[UInt16] # work area for code table building (288)
    var codes: UnsafePointer[Code]  # space for code tables (ENOUGH)
    var sane: Int                   # if false, allow invalid distance too far
    var back: Int                   # bits back of last unprocessed length/lit
    var was: UInt                   # initial length of match

    fn __init__(out self):
        """Initialize inflate state with default values."""
        self.strm = UnsafePointer[UInt8]()
        self.mode = InflateMode.HEAD
        self.last = 0
        self.wrap = 0
        self.havedict = 0
        self.flags = 0
        self.dmax = 0
        self.check = 0
        self.total = 0
        self.wbits = 0
        self.wsize = 0
        self.whave = 0
        self.wnext = 0
        self.window = UnsafePointer[UInt8]()
        self.hold = 0
        self.bits = 0
        self.length = 0
        self.offset = 0
        self.extra = 0
        self.lencode = UnsafePointer[Code]()
        self.distcode = UnsafePointer[Code]()
        self.lenbits = 0
        self.distbits = 0
        self.ncode = 0
        self.nlen = 0
        self.ndist = 0
        self.have = 0
        self.next = UnsafePointer[Code]()
        self.lens = UnsafePointer[UInt16]()
        self.work = UnsafePointer[UInt16]()
        self.codes = UnsafePointer[Code]()
        self.sane = 1
        self.back = -1
        self.was = 0


# Fixed decode tables sizes
alias FIXEDH = 544    # number of hlit code lengths
alias FIXEDD = 32     # number of hdist code distances

# Fixed literal/length code table (512 entries)
alias LENFIX_SIZE = 512
alias DISTFIX_SIZE = 32

# Fixed literal/length decode table from inffixed.h
alias LENFIX = InlineArray[Code, LENFIX_SIZE](
    # This is a large table - implement as function for better organization
    fill=Code()
)

# Fixed distance decode table from inffixed.h  
alias DISTFIX = InlineArray[Code, DISTFIX_SIZE](
    # Distance codes all use 5 bits
    fill=Code()
)


fn init_fixed_tables() -> (InlineArray[Code, LENFIX_SIZE], InlineArray[Code, DISTFIX_SIZE]):
    """Initialize fixed Huffman decode tables using proper table generation.
    
    Returns:
        Tuple of (lenfix, distfix) tables for fixed block decoding.
    """
    from .inftrees import inflate_table, CodeType
    from memory import UnsafePointer
    
    # Create code length arrays for fixed Huffman codes
    var lens = UnsafePointer[UInt16].alloc(288)  # 288 literal/length codes
    var work = UnsafePointer[UInt16].alloc(288)  # Work array
    
    # Set up code lengths for fixed Huffman table
    # Literals 0-143: 8 bits
    for i in range(144):
        lens[i] = 8
    # Literals 144-255: 9 bits  
    for i in range(144, 256):
        lens[i] = 9
    # Length codes 256-279: 7 bits
    for i in range(256, 280):
        lens[i] = 7
    # Length codes 280-287: 8 bits
    for i in range(280, 288):
        lens[i] = 8
    
    # Use the proper inflate_table function to build the tables correctly
    var lenfix = InlineArray[Code, LENFIX_SIZE](fill=Code())
    var table_ptr = UnsafePointer(to=lenfix[0])
    var table_bits = UInt(9)  # Root table size for fixed Huffman
    var result = inflate_table(CodeType.LENS, lens, 288, table_ptr, table_bits, work)
    
    if result != 0:
        # Table generation failed, clean up and error
        lens.free()
        work.free()
        # Return empty tables - caller should handle this
        return (lenfix, InlineArray[Code, DISTFIX_SIZE](fill=Code()))
    
    # Build distance table directly - all 32 codes use 5 bits and map directly
    var distfix = InlineArray[Code, DISTFIX_SIZE](fill=Code())
    
    # For fixed Huffman, distance codes are simple: 5 bits each, direct mapping
    # Bit pattern i maps to distance code i for i = 0..31
    for i in range(32):
        distfix[i] = Code(op=0, bits=5, val=UInt16(i))
    
    # Debug: Print some key table entries (commented out for now)
    # @parameter  
    # if not USE_ZLIB:
    #     print("DEBUG: Huffman table entries:")
    #     print("  Entry 0:", lenfix[0].__str__())
    #     print("  Entry 15:", lenfix[15].__str__())
    #     print("  Entry 256:", lenfix[256].__str__())
    #     if LENFIX_SIZE > 300:
    #         print("  Entry 300:", lenfix[300].__str__())
    
    # Clean up
    lens.free()
    work.free()
    
    return (lenfix, distfix)


# Bit manipulation macros as functions
fn needbits(state: InflateState, n: UInt) -> Bool:
    """Check if we need more bits in the bit accumulator.
    
    Args:
        state: Inflate state.
        n: Number of bits needed.
        
    Returns:
        True if more bits are needed.
    """
    return state.bits < n


fn bits(state: InflateState, n: UInt) -> UInt:
    """Extract n bits from the bit accumulator.
    
    Args:
        state: Inflate state.
        n: Number of bits to extract.
        
    Returns:
        The extracted bits.
    """
    return UInt(state.hold & ((1 << n) - 1))


fn dropbits(mut state: InflateState, n: UInt):
    """Drop n bits from the bit accumulator.
    
    Args:
        state: Inflate state to modify.
        n: Number of bits to drop.
    """
    state.hold >>= n
    state.bits -= n


fn bytebits(mut state: InflateState):
    """Round down to next byte boundary and discard remaining bits.
    
    Args:
        state: Inflate state to modify.
    """
    state.hold >>= state.bits & 7
    state.bits -= state.bits & 7


# Window size constants
alias MAX_WBITS = 15        # 32K LZ77 window
alias DEF_WBITS = MAX_WBITS # default window size

# Other inflate constants
alias INFLATE_STRICT = 1   # strict decoding mode
alias INFLATE_ALLOW = 0    # allow invalid distance too far