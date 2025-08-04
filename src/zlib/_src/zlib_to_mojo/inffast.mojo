"""Fast decompression for distance/length copying.

Based on inffast.c from zlib 1.3.1.1.
This module provides the fast path for literal/length/distance decoding
when sufficient input/output buffers are available.
"""

from memory import UnsafePointer
from .inflate_constants import InflateState, InflateMode
from .inftrees import Code
from ..constants import USE_ZLIB


fn inflate_fast(
    strm_next_in: UnsafePointer[UInt8],
    strm_avail_in: UInt,
    strm_next_out: UnsafePointer[UInt8], 
    strm_avail_out: UInt,
    mut state: InflateState,
    start: UInt
) -> (UInt, UInt, InflateState):
    """Fast decoding of literal, length, and distance codes.
    
    Decode literal, length, and distance codes and write out the resulting
    literal and match bytes until either not enough input or output is
    available, an end-of-block is encountered, or a data error is encountered.
    
    Entry assumptions:
    - state.mode == InflateMode.LEN
    - strm_avail_in >= 6
    - strm_avail_out >= 258
    - start >= strm_avail_out
    - state.bits < 8
    
    Args:
        strm_next_in: Input buffer pointer.
        strm_avail_in: Available input bytes.
        strm_next_out: Output buffer pointer.
        strm_avail_out: Available output space.
        state: Inflate state (modified).
        start: Initial available output.
        
    Returns:
        Tuple of (consumed_input, produced_output, updated_state).
        On return, state.mode is one of:
        - LEN: ran out of enough output space or enough available input
        - TYPE: reached end of block code, inflate() to interpret next block  
        - BAD: error in block data
    """
    # Local variables matching C implementation
    var input = strm_next_in
    var last = strm_next_in + (strm_avail_in - 5)  # Have enough input while input < last
    var output = strm_next_out
    var beg = strm_next_out - (start - strm_avail_out)  # inflate()'s initial next_out
    var end = strm_next_out + (strm_avail_out - 257)   # While output < end, enough space available
    
    var wsize = state.wsize          # Window size or zero if not using window
    var whave = state.whave          # Valid bytes in the window
    var wnext = state.wnext          # Window write index
    var window = state.window        # Allocated sliding window, if wsize != 0
    var hold = state.hold            # Local hold
    var bits = state.bits            # Local bits
    var lcode = state.lencode        # Local lencode
    var dcode = state.distcode       # Local distcode
    var lmask = (1 << state.lenbits) - 1  # Mask for first level of length codes
    var dmask = (1 << state.distbits) - 1 # Mask for first level of distance codes
    
    # Local loop variables
    var here = Code()                # Retrieved table entry
    var op: UInt = 0                 # Code bits, operation, extra bits, or window position
    var len: UInt = 0                # Match length, unused bytes
    var dist: UInt = 0               # Match distance
    var from_ptr = UnsafePointer[UInt8]() # Where to copy match from
    
    # Decode literals and length/distances until end-of-block or not enough input/output
    while True:
        # Ensure we have at least 15 bits in hold
        if bits < 15:
            if input >= last:
                break  # Not enough input
            hold += UInt64(input[0]) << bits
            input += 1
            bits += 8
            if input >= last:
                break  # Not enough input
            hold += UInt64(input[0]) << bits
            input += 1
            bits += 8
        
        # Get length/literal code
        here = lcode[Int(hold & lmask)]
        
        # Debug bit accumulator
        # @parameter
        # if not USE_ZLIB:
        #     if iteration_count <= 3:
        #         print("DEBUG iter", iteration_count, ": hold =", hex(hold), "lmask =", hex(lmask), "index =", Int(hold & lmask))
        
        # Process length/literal code
        op = UInt(here.op)
        hold >>= UInt(here.bits)
        bits -= UInt(here.bits)
        
        # Debug: Check for potential end-of-block
        # @parameter
        # if not USE_ZLIB:
        #     if here.val == 256:  # End-of-block symbol
        #         print("DEBUG: End-of-block symbol detected, op =", op)
        
        if op == 0:  # Literal
            if output >= end:
                break  # Not enough output space
            output[0] = UInt8(here.val)
            output += 1
            # Debug: Track literal count
            # @parameter
            # if not USE_ZLIB:
            #     if iteration_count <= 3:  # Only show first few iterations
            #         print("DEBUG iter", iteration_count, ": Literal val =", here.val, "op =", here.op, "bits =", here.bits)
            
        elif (op & 16) != 0:  # Length base
            len = UInt(here.val)
            op &= 15  # Number of extra bits
            if op != 0:
                if bits < op:
                    if input >= last:
                        break  # Not enough input
                    hold += UInt64(input[0]) << bits
                    input += 1
                    bits += 8
                len += UInt(hold & ((1 << op) - 1))
                hold >>= op
                bits -= op
            
            # Ensure we have at least 15 bits for distance code
            if bits < 15:
                if input >= last:
                    break  # Not enough input
                hold += UInt64(input[0]) << bits
                input += 1
                bits += 8
                if input >= last:
                    break  # Not enough input
                hold += UInt64(input[0]) << bits
                input += 1
                bits += 8
            
            # Get distance code
            here = dcode[Int(hold & dmask)]
            
            # Process distance code
            op = UInt(here.op)
            hold >>= UInt(here.bits)
            bits -= UInt(here.bits)
            
            if (op & 16) != 0:  # Distance base
                dist = UInt(here.val)
                op &= 15  # Number of extra bits
                if bits < op:
                    if input >= last:
                        break  # Not enough input
                    hold += UInt64(input[0]) << bits
                    input += 1
                    bits += 8
                    if bits < op:
                        if input >= last:
                            break  # Not enough input
                        hold += UInt64(input[0]) << bits
                        input += 1
                        bits += 8
                
                dist += UInt(hold & ((1 << op) - 1))
                hold >>= op
                bits -= op
                
                # Check for invalid distance in strict mode
                if state.sane != 0:
                    var max_dist = UInt(Int(output) - Int(beg))  # Max distance in output
                    if dist > max_dist + whave:
                        state.mode = InflateMode.BAD
                        break
                
                # Copy match
                var success, new_output = _copy_match(output, end, dist, len, beg, window, wsize, whave, wnext)
                if success:
                    output = new_output
                else:
                    break  # Not enough output space
                    
            elif op == 0:  # 2nd level distance code
                # Handle 2nd level distance codes
                var last_code = here
                if bits < UInt(last_code.bits + last_code.op):
                    if input >= last:
                        break  # Not enough input
                    hold += UInt64(input[0]) << bits
                    input += 1
                    bits += 8
                    if bits < UInt(last_code.bits + last_code.op):
                        if input >= last:
                            break  # Not enough input
                        hold += UInt64(input[0]) << bits
                        input += 1
                        bits += 8
                
                here = dcode[Int(UInt16(last_code.val) + UInt16((hold & UInt64((1 << (last_code.bits + last_code.op)) - 1)) >> UInt64(last_code.bits)))]
                hold >>= UInt64(last_code.bits)
                bits -= UInt(last_code.bits)
                op = UInt(here.op)
                
                if (op & 16) != 0:  # Distance base
                    dist = UInt(here.val)
                    op &= 15  # Number of extra bits
                    if bits < op:
                        if input >= last:
                            break  # Not enough input
                        hold += UInt64(input[0]) << bits
                        input += 1
                        bits += 8
                        if bits < op:
                            if input >= last:
                                break  # Not enough input
                            hold += UInt64(input[0]) << bits
                            input += 1
                            bits += 8
                    
                    dist += UInt(hold & ((1 << op) - 1))
                    hold >>= op
                    bits -= op
                    
                    # Check for invalid distance in strict mode
                    if state.sane != 0:
                        var max_dist = UInt(Int(output) - Int(beg))  # Max distance in output
                        if dist > max_dist + whave:
                            state.mode = InflateMode.BAD
                            break
                    
                    # Copy match
                    var success2, new_output2 = _copy_match(output, end, dist, len, beg, window, wsize, whave, wnext)
                    if success2:
                        output = new_output2
                    else:
                        break  # Not enough output space
                else:
                    state.mode = InflateMode.BAD
                    break
                
            else:  # Invalid distance code
                state.mode = InflateMode.BAD
                break
                
        elif (op & 32) != 0:  # End-of-block
            # Check if this was the last block
            if state.last != 0:
                state.mode = InflateMode.CHECK  # Last block, go to checksum
            else:
                state.mode = InflateMode.TYPE   # More blocks to process
            break
            
        elif (op & 64) == 0:  # 2nd level length code
            # Handle 2nd level length codes 
            var last_code = here
            if bits < UInt(last_code.bits + last_code.op):
                if input >= last:
                    break  # Not enough input
                hold += UInt64(input[0]) << bits
                input += 1
                bits += 8
                if bits < UInt(last_code.bits + last_code.op):
                    if input >= last:
                        break  # Not enough input
                    hold += UInt64(input[0]) << bits
                    input += 1
                    bits += 8
            
            here = lcode[Int(UInt16(last_code.val) + UInt16((hold & UInt64((1 << (last_code.bits + last_code.op)) - 1)) >> UInt64(last_code.bits)))]
            hold >>= UInt64(last_code.bits)
            bits -= UInt(last_code.bits)
            
            # Process the 2nd level code (continue from top of loop)
            continue
            
        else:  # Invalid length code
            state.mode = InflateMode.BAD
            break
    
    # Update state from local variables
    state.hold = hold
    state.bits = bits
    
    # Calculate consumed input and produced output
    var consumed_input = UInt(Int(input) - Int(strm_next_in))
    var produced_output = UInt(Int(output) - Int(strm_next_out))
    
    # @parameter
    # if not USE_ZLIB:
    #     print("DEBUG inffast: consumed =", consumed_input, "produced =", produced_output, "mode =", UInt(state.mode))
    
    return (consumed_input, produced_output, state)


fn _copy_match(
    mut output: UnsafePointer[UInt8],
    end: UnsafePointer[UInt8],
    dist: UInt,
    mut len: UInt,
    beg: UnsafePointer[UInt8],
    window: UnsafePointer[UInt8],
    wsize: UInt,
    whave: UInt,
    wnext: UInt
) -> (Bool, UnsafePointer[UInt8]):
    """Copy a match from either the sliding window or recent output.
    
    Args:
        output: Current output position (modified).
        end: End of available output space.
        dist: Distance back to copy from.
        len: Length to copy.
        beg: Beginning of output buffer.
        window: Sliding window buffer.
        wsize: Window size.
        whave: Valid bytes in window.
        wnext: Window write index.
        
    Returns:
        Tuple of (success, new_output_position). True if copy was successful, False if not enough output space.
    """
    var from_ptr = UnsafePointer[UInt8]()
    var op = UInt(Int(output) - Int(beg))  # Max distance in output
    
    if dist > op:  # Copy from window
        op = dist - op  # Distance back in window
        if op > whave:
            # Invalid distance - would need special handling in full implementation
            return (False, output)
            
        from_ptr = window
        if wnext == 0:  # Very common case
            from_ptr += wsize - op
            if op < len:  # Some from window
                if output + op > end:
                    return (False, output)  # Not enough output space
                len -= op
                while op > 0:
                    output[0] = from_ptr[0]
                    output += 1
                    from_ptr += 1
                    op -= 1
                from_ptr = output - dist  # Rest from output
        elif wnext < op:  # Wrap around window
            from_ptr += wsize + wnext - op
            op -= wnext
            if op < len:  # Some from end of window
                if output + op > end:
                    return (False, output)  # Not enough output space
                len -= op
                while op > 0:
                    output[0] = from_ptr[0]
                    output += 1
                    from_ptr += 1
                    op -= 1
                from_ptr = window
                if wnext < len:  # Some from start of window
                    op = wnext
                    if output + op > end:
                        return (False, output)  # Not enough output space
                    len -= op
                    while op > 0:
                        output[0] = from_ptr[0]
                        output += 1
                        from_ptr += 1
                        op -= 1
                    from_ptr = output - dist  # Rest from output
        else:  # Contiguous in window
            from_ptr += wnext - op
            if op < len:  # Some from window
                if output + op > end:
                    return (False, output)  # Not enough output space
                len -= op
                while op > 0:
                    output[0] = from_ptr[0]
                    output += 1
                    from_ptr += 1
                    op -= 1
                from_ptr = output - dist  # Rest from output
        
        # Copy remaining bytes with optimization for runs of 3
        if output + len > end:
            return (False, output)  # Not enough output space
        while len > 2:
            output[0] = from_ptr[0]
            output[1] = from_ptr[1]
            output[2] = from_ptr[2]
            output += 3
            from_ptr += 3
            len -= 3
        if len > 0:
            output[0] = from_ptr[0]
            output += 1
            from_ptr += 1
            if len > 1:
                output[0] = from_ptr[0]
                output += 1
                from_ptr += 1
    else:
        # Copy direct from output
        from_ptr = output - dist
        if output + len > end:
            return (False, output)  # Not enough output space
        
        # Fast copy for small distances
        if dist == 1:
            # Special case: run of same byte
            var byte_val = from_ptr[0]
            while len > 0:
                output[0] = byte_val
                output += 1
                len -= 1
        elif dist < len:
            # Overlapping copy - must copy byte by byte
            while len > 0:
                output[0] = from_ptr[0]
                output += 1
                from_ptr += 1
                len -= 1
        else:
            # Non-overlapping copy - can copy in chunks
            while len > 2:
                output[0] = from_ptr[0]
                output[1] = from_ptr[1]
                output[2] = from_ptr[2]
                output += 3
                from_ptr += 3
                len -= 3
            if len > 0:
                output[0] = from_ptr[0]
                output += 1
                from_ptr += 1
                if len > 1:
                    output[0] = from_ptr[0]
                    output += 1
                    from_ptr += 1
    
    return (True, output)


# Constants for fast path requirements
alias INFLATE_FAST_MIN_HAVE = 6    # Minimum input bytes required
alias INFLATE_FAST_MIN_LEFT = 258  # Minimum output space required