# Pure Mojo checksum implementations


fn adler32(data: Span[UInt8], value: UInt32 = 1) -> UInt32:
    """Computes an Adler-32 checksum of data.

    An Adler-32 checksum is almost as reliable as a CRC32 but can be computed much faster.
    The result is an unsigned 32-bit integer. If value is present, it is used as the
    starting value of the checksum; otherwise, a default value of 1 is used.
    Passing the value returned by a previous call allows computing a running checksum
    over the concatenation of several inputs.

    The algorithm is defined in RFC 1950 and produces the same results as the
    adler32() function in the zlib library.

    Args:
        data: The data to compute the checksum for.
        value: Starting value of the checksum (default: 1). Can be the result
               of a previous adler32() call to compute a running checksum.

    Returns:
        An unsigned 32-bit integer representing the Adler-32 checksum.
    """
    alias BASE = 65521  # Largest prime less than 65536

    # Extract the two 16-bit parts from the starting value
    var a = value & 0xFFFF
    var b = (value >> 16) & 0xFFFF

    # Process each byte
    for byte in data:
        a = (a + UInt32(byte)) % BASE
        b = (b + a) % BASE

    # Combine the two parts into the final 32-bit checksum
    return (b << 16) | a


fn generate_crc_32_table() -> InlineArray[UInt32, 256]:
    table = InlineArray[UInt32, 256](fill=0)
    for i in range(256):
        crc = UInt32(i)
        for _ in range(8):
            if (crc & 1) != 0:
                crc = (crc >> 1) ^ 0xEDB88320
            else:
                crc >>= 1
        table[i] = crc
    return table


alias CRC32Table = generate_crc_32_table()


fn crc32(data: Span[UInt8], value: UInt32 = 0) -> UInt32:
    """Computes a CRC (Cyclic Redundancy Check) checksum of data.

    This computes a 32-bit checksum of data. The result is an unsigned 32-bit integer.
    If value is present, it is used as the starting value of the checksum; otherwise,
    a default value of 0 is used. Passing the value returned by a previous call allows
    computing a running checksum over the concatenation of several inputs.

    The algorithm produces the same results as the crc32() function in the zlib library
    and is compatible with the zipfile module.

    Args:
        data: The data to compute the checksum for.
        value: Starting value of the checksum (default: 0). Can be the result
               of a previous crc32() call to compute a running checksum.

    Returns:
        An unsigned 32-bit integer representing the CRC-32 checksum.
    """
    # Initialize CRC with inverted starting value (CRC-32 starts with 0xFFFFFFFF)
    var crc = ~value

    for byte in data:
        crc = CRC32Table[(crc ^ UInt32(byte)) & UInt32(0xFF)] ^ (crc >> 8)

    # Return final CRC (inverted)
    return ~crc
