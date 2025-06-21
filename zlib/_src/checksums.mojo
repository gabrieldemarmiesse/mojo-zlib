# Pure Mojo checksum implementations


fn adler32(data: Span[UInt8], value: UInt32 = 1) -> UInt32:
    """Computes an Adler-32 checksum of data.

    This function implements the Adler-32 algorithm in pure Mojo, avoiding
    the need for dynamic library dependencies. The algorithm is defined in RFC 1950
    and is used in the zlib compression library.

    The Adler-32 checksum is computed as:
    - a = 1 + d1 + d2 + ... + dn (mod 65521)
    - b = (1 + d1) + (1 + d1 + d2) + ... + (1 + d1 + d2 + ... + dn) (mod 65521)
    - Adler-32(D) = b * 65536 + a

    Args:
        data: The data to compute the checksum for (as a Span).
        value: Starting value of the checksum (default: 1).

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
    """Computes a CRC-32 checksum of data.

    This function implements the same CRC-32 algorithm.
    It follows the same algorithm used in the zipfile module in Python.
    Reference: https://github.com/python/cpython/blob/main/Modules/binascii.c#L739

    Args:
        data: The data to compute the checksum for (as a Span)
        value: Starting value of the checksum (default: 0)

    Returns:
        An unsigned 32-bit integer representing the CRC-32 checksum
    """
    # Initialize CRC with inverted starting value (CRC-32 starts with 0xFFFFFFFF)
    var crc = ~value

    for byte in data:
        crc = CRC32Table[(crc ^ UInt32(byte)) & UInt32(0xFF)] ^ (crc >> 8)

    # Return final CRC (inverted)
    return ~crc
