"""Main decompression logic for inflate.

Based on inflate.c from zlib 1.3.1.1.
This module provides the main inflate decompression state machine
that processes zlib, gzip, and raw deflate formats.
"""

from memory import UnsafePointer, memset_zero
from .inflate_constants import InflateState, InflateMode, init_fixed_tables
from .inftrees import inflate_table, CodeType, Code
from .inffast import inflate_fast, INFLATE_FAST_MIN_HAVE, INFLATE_FAST_MIN_LEFT
from .zutil import zcalloc, zcfree

# Return codes
alias Z_OK = 0
alias Z_STREAM_ERROR = -2
alias Z_DATA_ERROR = -3
alias Z_MEM_ERROR = -4
alias Z_BUF_ERROR = -5
alias Z_NEED_DICT = 2
alias Z_STREAM_END = 1

# Compression methods
alias Z_DEFLATED = 8

# Window size constants
alias DEF_WBITS = 15
alias MAX_WBITS = 15

# Code length order for dynamic Huffman tables
alias CODE_LENGTH_ORDER = InlineArray[UInt8, 19](
    16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15
)


fn inflate_init(mut state: InflateState, wbits: Int) -> Int:
    """Initialize inflate state for decompression.
    
    Args:
        state: Inflate state to initialize.
        wbits: Window bits parameter.
        
    Returns:
        Z_OK on success, error code on failure.
    """
    # Initialize state
    state.mode = InflateMode.HEAD
    state.last = 0
    state.havedict = 0
    state.dmax = 32768  # Default max distance
    state.check = 1     # Adler32 initial value
    state.total = 0
    
    # Set up window
    if wbits < 0:
        state.wrap = 0
        state.wbits = UInt(-wbits)
    elif wbits == 0:
        state.wbits = DEF_WBITS
        state.wrap = 1
    elif wbits > 15:
        state.wrap = 2  # gzip format
        state.wbits = UInt(wbits - 16)
    else:
        state.wrap = 1  # zlib format
        state.wbits = UInt(wbits)
    
    if state.wbits < 8 or state.wbits > 15:
        return Z_STREAM_ERROR
    
    state.wsize = 1 << state.wbits
    state.whave = 0
    state.wnext = 0
    
    # Initialize bit accumulator
    state.hold = 0
    state.bits = 0
    
    # Initialize other state
    state.sane = 1
    state.back = -1
    
    return Z_OK


fn inflate_reset(mut state: InflateState) -> Int:
    """Reset inflate state for new stream.
    
    Args:
        state: Inflate state to reset.
        
    Returns:
        Z_OK on success.
    """
    state.mode = InflateMode.HEAD
    state.last = 0
    state.havedict = 0
    state.check = 1  # Adler32 initial value
    state.total = 0
    state.whave = 0
    state.wnext = 0
    state.hold = 0
    state.bits = 0
    state.back = -1
    
    return Z_OK


fn inflate_main(
    input_data: UnsafePointer[UInt8],
    input_len: UInt,
    output_data: UnsafePointer[UInt8], 
    output_len: UInt,
    mut state: InflateState
) -> (UInt, UInt, Int, InflateState):
    """Main inflate decompression function.
    
    Args:
        input_data: Input buffer pointer.
        input_len: Available input bytes.
        output_data: Output buffer pointer.
        output_len: Available output space.
        state: Inflate state (modified).
        
    Returns:
        Tuple of (consumed_input, produced_output, return_code, updated_state).
    """
    # Local variables
    var input = input_data
    var input_end = input_data + input_len
    var output = output_data
    var output_end = output_data + output_len
    var ret = Z_OK
    
    # Bit manipulation variables
    var hold = state.hold
    var bits = state.bits
    
    # Main decompression state machine
    while True:
        if state.mode == InflateMode.HEAD:
            # Process header
            if state.wrap == 0:
                state.mode = InflateMode.TYPEDO
                continue
                
            # Need 16 bits for header
            if bits < 16:
                if input >= input_end:
                    break  # Need more input
                hold += UInt64(input[0]) << bits
                input += 1
                bits += 8
                if input >= input_end:
                    break  # Need more input
                hold += UInt64(input[0]) << bits
                input += 1
                bits += 8
            
            # Check zlib header
            if state.wrap == 1:  # zlib format
                # Convert from little-endian to big-endian for zlib checksum
                var header_be = ((hold & 0xFF) << 8) | ((hold >> 8) & 0xFF)
                if header_be % 31 != 0:
                    state.mode = InflateMode.BAD
                    ret = Z_DATA_ERROR
                    break
                
                if (hold & 0xF) != Z_DEFLATED:
                    state.mode = InflateMode.BAD
                    ret = Z_DATA_ERROR
                    break
                    
                hold >>= 4
                bits -= 4
                var len = UInt((hold & 0xF) + 8)
                if len > state.wbits:
                    state.mode = InflateMode.BAD
                    ret = Z_DATA_ERROR
                    break
                    
                # Check for preset dictionary 
                var dict_flag = (hold & 0x20) != 0  # Check bit 5 (dictionary bit in FLG)
                
                # Clear bit accumulator to start fresh with deflate data (like INITBITS() in C)
                hold = 0
                bits = 0
                
                if dict_flag:
                    state.mode = InflateMode.DICTID
                else:
                    state.mode = InflateMode.TYPE
                
            elif state.wrap == 2:  # gzip format - simplified header skip
                print("GZIP: processing gzip header, skipping to deflate data")
                # Skip gzip header - minimal implementation
                # Gzip header is at least 10 bytes, more complex parsing needed
                # For now, return error since proper gzip parsing isn't implemented
                state.mode = InflateMode.BAD
                ret = Z_DATA_ERROR
                break
            else:
                state.mode = InflateMode.TYPEDO
                
        elif state.mode == InflateMode.DICTID:
            # Dictionary ID for zlib format
            if bits < 32:
                while bits < 32 and input < input_end:
                    hold += UInt64(input[0]) << bits
                    input += 1
                    bits += 8
                if bits < 32:
                    break  # Need more input
            
            # For now, just return need dictionary error
            ret = Z_NEED_DICT
            break
            
        elif state.mode == InflateMode.TYPE:
            
            # Get block type
            if state.last != 0:
                state.mode = InflateMode.CHECK
                continue
                
            # Need at least 3 bits for block header
            while bits < 3:
                if input >= input_end:
                    break  # Need more input
                hold += UInt64(input[0]) << bits
                input += 1
                bits += 8
            
            state.last = Int(hold & 1)
            hold >>= 1
            bits -= 1
            
            var block_type = Int(hold & 3)
            hold >>= 2
            bits -= 2
            
            if block_type == 0:  # Stored block
                state.mode = InflateMode.STORED
            elif block_type == 1:  # Fixed Huffman
                var lenfix, distfix = init_fixed_tables()
                state.lencode = UnsafePointer(to=lenfix[0])
                state.distcode = UnsafePointer(to=distfix[0])
                state.lenbits = 9
                state.distbits = 5
                state.mode = InflateMode.LEN_
            elif block_type == 2:  # Dynamic Huffman
                state.mode = InflateMode.TABLE
            else:  # Invalid block type
                state.mode = InflateMode.BAD
                ret = Z_DATA_ERROR
                break
                
        elif state.mode == InflateMode.TYPEDO:
            # Skip to next block without header checks
            state.mode = InflateMode.TYPE
            
        elif state.mode == InflateMode.STORED:
            # Stored (uncompressed) block
            # Align to byte boundary
            hold >>= bits & 7
            bits -= bits & 7
            
            # Get length
            if bits < 32:
                while bits < 32 and input < input_end:
                    hold += UInt64(input[0]) << bits
                    input += 1
                    bits += 8
                if bits < 32:
                    state.mode = InflateMode.BAD
                    ret = Z_DATA_ERROR
                    break
            
            var length = UInt(hold & 0xFFFF)
            var nlength = UInt((hold >> 16) & 0xFFFF)
            hold = 0
            bits = 0
            
            if length != (nlength ^ 0xFFFF):
                state.mode = InflateMode.BAD
                ret = Z_DATA_ERROR
                break
                
            # Copy stored data
            if length > 0:
                var copy_len = min(length, UInt(Int(input_end) - Int(input)))
                copy_len = min(copy_len, UInt(Int(output_end) - Int(output)))
                
                if copy_len == 0:
                    break  # Need more input or output space
                    
                for i in range(copy_len):
                    output[i] = input[i]
                    
                input += copy_len
                output += copy_len
                
                if copy_len < length:
                    break  # Need more input or output space
                    
            state.mode = InflateMode.TYPE
            
        elif state.mode == InflateMode.TABLE:
            # Dynamic Huffman table processing
            ret = _process_dynamic_table(input, input_end, output, output_end, state, hold, bits)
            # Update local bit accumulator from state
            hold = state.hold
            bits = state.bits
            if ret != Z_OK:
                break
                
        elif state.mode == InflateMode.LEN_:
            # First time in LEN state
            state.mode = InflateMode.LEN
            # Fall through
            
        elif state.mode == InflateMode.LEN:
            # Decode literal/length/distance codes
            # Always try fast path first, as it handles length/distance codes properly
            if (UInt(Int(input_end) - Int(input)) >= INFLATE_FAST_MIN_HAVE and 
                UInt(Int(output_end) - Int(output)) >= INFLATE_FAST_MIN_LEFT):
                
                # Update state with current bit accumulator
                state.hold = hold
                state.bits = bits
                
                # Use fast path
                var consumed, produced, new_state = inflate_fast(
                    input, UInt(Int(input_end) - Int(input)),
                    output, UInt(Int(output_end) - Int(output)),
                    state, UInt(Int(output_end) - Int(output_data))
                )
                
                input += consumed
                output += produced
                state = new_state
                hold = state.hold
                bits = state.bits
                
                if state.mode == InflateMode.TYPE:
                    continue
                elif state.mode == InflateMode.BAD:
                    ret = Z_DATA_ERROR
                    break
                # Fast path completed successfully, continue processing
                continue
            
            # Slow path - decode one symbol at a time (limited functionality)  
            # Update state with current bit accumulator first
            state.hold = hold
            state.bits = bits
            
            ret = _decode_slow_path(input, input_end, output, output_end, state, hold, bits)
            
            # Update local variables from state
            hold = state.hold
            bits = state.bits
            
            if ret != Z_OK:
                break
                
        elif state.mode == InflateMode.CHECK:
            # Check trailer (Adler32 for zlib, CRC32 for gzip)
            if state.wrap == 1:  # zlib format
                if bits < 32:
                    while bits < 32 and input < input_end:
                        hold += UInt64(input[0]) << bits
                        input += 1
                        bits += 8
                    if bits < 32:
                        break  # Need more input
                
                # For now, just skip checksum verification
                hold = 0
                bits = 0
                
            state.mode = InflateMode.DONE
            ret = Z_STREAM_END
            break
            
        elif state.mode == InflateMode.DONE:
            # Decompression complete
            ret = Z_STREAM_END
            break
            
        elif state.mode == InflateMode.BAD:
            # Error state
            ret = Z_DATA_ERROR
            break
            
        else:
            # Unknown state
            ret = Z_STREAM_ERROR
            break
    
    # Update state
    state.hold = hold
    state.bits = bits
    
    # Calculate consumed and produced bytes
    var consumed_input = UInt(Int(input) - Int(input_data))
    var produced_output = UInt(Int(output) - Int(output_data))
    
    return (consumed_input, produced_output, ret, state)


fn _process_dynamic_table(
    mut input: UnsafePointer[UInt8],
    input_end: UnsafePointer[UInt8],
    output: UnsafePointer[UInt8],
    output_end: UnsafePointer[UInt8],
    mut state: InflateState,
    mut hold: UInt64,
    mut bits: UInt
) -> Int:
    """Process dynamic Huffman table.
    
    Implementation of the dynamic Huffman table decoding process
    as specified in RFC 1951 (DEFLATE).
    """
    from .inftrees import inflate_table, CodeType
    
    # Get number of literal/length and distance codes
    if bits < 14:
        while bits < 14 and input < input_end:
            hold += UInt64(input[0]) << bits
            input += 1
            bits += 8
        if bits < 14:
            return Z_BUF_ERROR  # Need more input
    
    # Read HLIT, HDIST, HCLEN values (RFC 1951)
    state.nlen = UInt((hold & 0x1F) + 257)  # Number of literal/length codes (257-286)
    hold >>= 5
    bits -= 5
    
    state.ndist = UInt((hold & 0x1F) + 1)   # Number of distance codes (1-32)
    hold >>= 5
    bits -= 5
    
    state.ncode = UInt((hold & 0xF) + 4)    # Number of code length codes (4-19)
    hold >>= 4
    bits -= 4
    
    # Validate table sizes
    if state.nlen > 286 or state.ndist > 30:
        state.mode = InflateMode.BAD
        return Z_DATA_ERROR
    
    # Initialize lens array if not already done
    if not state.lens:
        state.lens = UnsafePointer[UInt16].alloc(320)  # 286 + 32 + extra space
    
    # Clear the lens array
    for i in range(320):
        state.lens[i] = 0
    
    # Read code length codes in the specific order
    state.have = 0
    while state.have < state.ncode:
        # Need 3 bits for each code length
        while bits < 3:
            if input >= input_end:
                return Z_BUF_ERROR  # Need more input
            hold += UInt64(input[0]) << bits
            input += 1
            bits += 8
        
        # Store code length in the proper order
        state.lens[Int(CODE_LENGTH_ORDER[Int(state.have)])] = UInt16(hold & 0x7)
        hold >>= 3
        bits -= 3
        state.have += 1
    
    # Fill remaining code length positions with 0
    while state.have < 19:
        state.lens[Int(CODE_LENGTH_ORDER[Int(state.have)])] = 0
        state.have += 1
    
    # Build code length table for decoding the main tables
    if not state.codes:
        state.codes = UnsafePointer[Code].alloc(1444)  # ENOUGH space
    
    state.next = state.codes
    state.lencode = state.codes
    state.lenbits = 7
    
    var work = UnsafePointer[UInt16].alloc(320)
    var table_ptr = state.next
    var table_bits = state.lenbits
    var result = inflate_table(CodeType.CODES, state.lens, 19, table_ptr, table_bits, work)
    
    if result != 0:
        work.free()
        state.mode = InflateMode.BAD
        return Z_DATA_ERROR
    
    # Update table pointers
    state.lencode = state.codes
    state.lenbits = table_bits
    
    # Now decode the literal/length and distance code lengths
    state.have = 0
    while state.have < state.nlen + state.ndist:
        # Decode using code length table
        var here: Code
        while True:
            # Need enough bits for code length lookup
            while bits < Int(state.lenbits):
                if input >= input_end:
                    work.free()
                    return Z_BUF_ERROR
                hold += UInt64(input[0]) << bits
                input += 1
                bits += 8
            
            var lmask = (1 << state.lenbits) - 1
            here = state.lencode[Int(hold & lmask)]
            
            if UInt(here.bits) <= bits:
                break
            
            # This shouldn't happen with proper table
            work.free()
            state.mode = InflateMode.BAD
            return Z_DATA_ERROR
        
        # Process the decoded code length symbol
        if here.val < 16:
            # Direct code length (0-15)
            hold >>= UInt(here.bits)
            bits -= UInt(here.bits)
            state.lens[Int(state.have)] = UInt16(here.val)
            state.have += 1
        
        elif here.val == 16:
            # Repeat previous code length 3-6 times
            if state.have == 0:
                work.free()
                state.mode = InflateMode.BAD
                return Z_DATA_ERROR
            
            # Need bits for repeat count
            while bits < UInt(here.bits) + 2:
                if input >= input_end:
                    work.free()
                    return Z_BUF_ERROR
                hold += UInt64(input[0]) << bits
                input += 1
                bits += 8
            
            hold >>= UInt(here.bits)
            bits -= UInt(here.bits)
            
            var len = state.lens[Int(state.have - 1)]
            var copy = 3 + UInt(hold & 0x3)
            hold >>= 2
            bits -= 2
            
            if state.have + copy > state.nlen + state.ndist:
                work.free()
                state.mode = InflateMode.BAD
                return Z_DATA_ERROR
            
            for _ in range(copy):
                state.lens[Int(state.have)] = len
                state.have += 1
        
        elif here.val == 17:
            # Repeat zero 3-10 times
            while bits < UInt(here.bits) + 3:
                if input >= input_end:
                    work.free()
                    return Z_BUF_ERROR
                hold += UInt64(input[0]) << bits
                input += 1
                bits += 8
            
            hold >>= UInt(here.bits)
            bits -= UInt(here.bits)
            
            var copy = 3 + UInt(hold & 0x7)
            hold >>= 3
            bits -= 3
            
            if state.have + copy > state.nlen + state.ndist:
                work.free()
                state.mode = InflateMode.BAD
                return Z_DATA_ERROR
            
            for _ in range(copy):
                state.lens[Int(state.have)] = 0
                state.have += 1
        
        elif here.val == 18:
            # Repeat zero 11-138 times
            while bits < UInt(here.bits) + 7:
                if input >= input_end:
                    work.free()
                    return Z_BUF_ERROR
                hold += UInt64(input[0]) << bits
                input += 1
                bits += 8
            
            hold >>= UInt(here.bits)
            bits -= UInt(here.bits)
            
            var copy = 11 + UInt(hold & 0x7F)
            hold >>= 7
            bits -= 7
            
            if state.have + copy > state.nlen + state.ndist:
                work.free()
                state.mode = InflateMode.BAD
                return Z_DATA_ERROR
            
            for _ in range(copy):
                state.lens[Int(state.have)] = 0
                state.have += 1
        
        else:
            # Invalid code length symbol
            work.free()
            state.mode = InflateMode.BAD
            return Z_DATA_ERROR
    
    # Check for end-of-block code (must be present in literal/length table)
    if state.lens[256] == 0:
        work.free()
        state.mode = InflateMode.BAD
        return Z_DATA_ERROR
    
    # Build literal/length table
    state.next = state.codes
    state.lencode = state.codes
    state.lenbits = 9
    
    table_ptr = state.next
    table_bits = state.lenbits
    result = inflate_table(CodeType.LENS, state.lens, Int(state.nlen), table_ptr, table_bits, work)
    
    if result != 0:
        work.free()
        state.mode = InflateMode.BAD
        return Z_DATA_ERROR
    
    state.lencode = state.codes
    state.lenbits = table_bits
    
    # Build distance table
    state.distcode = state.next
    state.distbits = 6
    
    table_ptr = state.next
    table_bits = state.distbits
    result = inflate_table(CodeType.DISTS, state.lens + Int(state.nlen), Int(state.ndist), table_ptr, table_bits, work)
    
    if result != 0:
        work.free()
        state.mode = InflateMode.BAD
        return Z_DATA_ERROR
    
    state.distcode = state.next
    state.distbits = table_bits
    
    work.free()
    
    # Ready to decode with dynamic tables
    state.mode = InflateMode.LEN_
    
    # Update the caller's bit accumulator
    state.hold = hold
    state.bits = bits
    
    return Z_OK


fn _decode_slow_path(
    mut input: UnsafePointer[UInt8],
    input_end: UnsafePointer[UInt8],
    mut output: UnsafePointer[UInt8],
    output_end: UnsafePointer[UInt8],
    mut state: InflateState,
    mut hold: UInt64,
    mut bits: UInt
) -> Int:
    """Decode symbols one at a time (slow path).
    
    This is used when we don't have enough input/output for the fast path,
    or when we need more precise control over the decoding process.
    """
    # Ensure we have enough bits for symbol lookup
    if bits < 15:
        while bits < 15 and input < input_end:
            hold += UInt64(input[0]) << bits  
            input += 1
            bits += 8
        if bits < 15:
            return Z_BUF_ERROR  # Need more input
    
    # Look up symbol in length/literal table
    var lmask = (1 << state.lenbits) - 1
    var here = state.lencode[Int(hold & lmask)]
    
    # Process the code
    var consume_bits = UInt(here.bits)
    if consume_bits > bits:
        state.mode = InflateMode.BAD
        return Z_DATA_ERROR
    hold >>= consume_bits
    bits -= consume_bits
    
    var op = UInt(here.op)
    
    if op == 0:  # Literal
        if output >= output_end:
            return Z_BUF_ERROR  # Need more output space
        output[0] = UInt8(here.val)
        output += 1
        
    elif (op & 16) != 0:  # Length code
        # This would require distance code processing - simplified implementation
        # For now, just handle end-of-block (symbol 256) which has op with bit 5 set
        if here.val == 256:  # End of block symbol
            state.mode = InflateMode.TYPE
        else:
            state.mode = InflateMode.BAD
            return Z_DATA_ERROR
        
    elif (op & 32) != 0:  # End of block
        state.mode = InflateMode.TYPE
        
    else:  # Invalid code
        state.mode = InflateMode.BAD
        return Z_DATA_ERROR
    
    # Update state
    state.hold = hold
    state.bits = bits
    
    return Z_OK


# Helper functions
fn min(a: UInt, b: UInt) -> UInt:
    """Return minimum of two values."""
    return a if a < b else b