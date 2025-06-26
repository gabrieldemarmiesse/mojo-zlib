# mojo-zlib

A Mojo implementation of the Python zlib library, providing compression, decompression, and checksum functionality. This library offers a Python-compatible API for zlib operations in Mojo, enabling seamless migration from Python code.

## Installation with Pixi

Make sure that you have `https://repo.prefix.dev/mojo-community` in the `channels` list of your `pixi.toml` file.
Then, you can install the library with:

```bash
pixi add mojo-zlib
```

### Common issues:

If your IDE tells you "Cannot find module 'zlib'": you have to go to the extensions menu, look for the Mojo or Mojo nightly extension,
and click on the "Settings" icon. Then you'll find a section called "Mojo › Lsp: Include Dirs". Add the following path to the list:

```bash
.pixi/envs/default/lib/mojo
```
This is where Pixi adds the `.mojopkg` files.

Then restart your IDE or just the Mojo extension and it should work.

## Useful links:

- [Documentation](https://github.com/gabrieldemarmiesse/mojo-zlib)
- [Source Code](https://github.com/gabrieldemarmiesse/mojo-zlib)

## Features

- **Compression & Decompression**: Full support for DEFLATE algorithm with zlib, gzip, and raw deflate formats
- **Streaming Operations**: Incremental compression and decompression for large datasets
- **Checksum Functions**: Pure Mojo implementations of CRC32 and Adler-32 algorithms
- **Python Compatibility**: API designed to match Python's zlib module
- **Memory Efficient**: Streaming operations avoid loading entire datasets into memory


**Note** Those bindings are not as fast and they could be. We are currently waiting for several Mojo language features to improve the speed.

## Development

Run the unit tests with 

```bash
pixi run test
```

Install the pre-commit with 

```bash
pixi x pre-commit install
```

## Quick Start

```mojo
import zlib

fn main() raises:
    # Basic compression and decompression
    data = "Hello, World! This is a test string for compression.".as_bytes()
    compressed = zlib.compress(data)
    decompressed = zlib.decompress(compressed)
    
    # Streaming compression for large data
    compressor = zlib.compressobj()
    data_part1 = "First part of data ".as_bytes()
    data_part2 = "Second part of data".as_bytes()
    chunk1 = compressor.compress(data_part1)
    chunk2 = compressor.compress(data_part2) 
    final = compressor.flush()
    result = chunk1 + chunk2 + final
    
    # Checksum calculation
    crc = zlib.crc32(data)
    adler = zlib.adler32(data)
```

## API Reference

### Compression Functions

| Function | Signature |
|----------|-----------|
| [`compress`](#compress) | `fn compress(data: Span[UInt8], level: Int32 = -1, wbits: Int32 = MAX_WBITS) raises -> List[UInt8]` |
| [`compressobj`](#compressobj) | `fn compressobj(level: Int32 = -1, method: Int32 = Z_DEFLATED, wbits: Int32 = MAX_WBITS, memLevel: Int32 = DEF_MEM_LEVEL, strategy: Int32 = Z_DEFAULT_STRATEGY) raises -> Compress` |

### Decompression Functions

| Function | Signature |
|----------|-----------|
| [`decompress`](#decompress) | `fn decompress(data: Span[UInt8], wbits: Int32 = MAX_WBITS, bufsize: Int = DEF_BUF_SIZE) raises -> List[UInt8]` |
| [`decompressobj`](#decompressobj) | `fn decompressobj(wbits: Int32 = MAX_WBITS) raises -> Decompress` |

### Checksum Functions

Note that those are implemented in Mojo and thus do not require `libz.so` to be installed.

| Function | Signature |
|----------|-----------|
| [`crc32`](#crc32) | `fn crc32(data: Span[UInt8], value: UInt32 = 0) -> UInt32` |
| [`adler32`](#adler32) | `fn adler32(data: Span[UInt8], value: UInt32 = 1) -> UInt32` |

### Streaming Objects

| Object | Description |
|--------|-------------|
| [`Compress`](#compress-object) | Streaming compression object with `compress()` and `flush()` methods |
| [`Decompress`](#decompress-object) | Streaming decompression object with `decompress()`, `flush()`, and status attributes |

## Function Documentation

### compress

```mojo
fn compress(data: Span[UInt8], level: Int32 = -1, wbits: Int32 = MAX_WBITS) raises -> List[UInt8]
```

Compresses the bytes in data, returning a `List[UInt8]` containing compressed data.

**Parameters:**
- `data`: The data to compress
- `level`: Compression level from 0 to 9 controlling the compression speed/size tradeoff:
  - `0`: No compression
  - `1`: Fastest compression, least compression
  - `9`: Slowest compression, best compression
  - `-1`: Default compromise between speed and compression (equivalent to level 6)
- `wbits`: Window bits parameter controlling the compression format and window size:
  - `9` to `15`: zlib format with header and checksum
  - `-9` to `-15`: raw deflate format without header or checksum
  - `16 + (9 to 15)`: gzip format with header and checksum

**Returns:** Compressed data as `List[UInt8]`

**Raises:** `Error` if compression fails or invalid parameters are provided

### compressobj

```mojo
fn compressobj(level: Int32 = -1, method: Int32 = Z_DEFLATED, wbits: Int32 = MAX_WBITS, memLevel: Int32 = DEF_MEM_LEVEL, strategy: Int32 = Z_DEFAULT_STRATEGY) raises -> Compress
```

Return a compression object whose `compress()` method takes a `Span[UInt8]` and returns compressed data for a portion of the data.

The returned object also has `flush()` methods. This allows for incremental compression; it can be more efficient when compressing very large amounts of data.

**Parameters:**
- `level`: Compression level (same as `compress()`)
- `method`: The compression algorithm. Currently, only `DEFLATED` is supported
- `wbits`: Window bits parameter (same as `compress()`)
- `memLevel`: Controls memory used for compression. Valid values 1-9. Higher values use more memory but are faster
- `strategy`: Compression strategy: `Z_DEFAULT_STRATEGY`, `Z_FILTERED`, `Z_HUFFMAN_ONLY`, `Z_RLE`, `Z_FIXED`

**Returns:** A `Compress` object for incremental compression

**Raises:** `Error` if compression initialization fails or invalid parameters provided

### decompress

```mojo
fn decompress(data: Span[UInt8], wbits: Int32 = MAX_WBITS, bufsize: Int = DEF_BUF_SIZE) raises -> List[UInt8]
```

Decompresses the bytes in data, returning a bytes object containing the uncompressed data.

**Parameters:**
- `data`: The compressed data to decompress
- `wbits`: Window bits parameter controlling the compression format and window size:
  - `9` to `15`: zlib format with header and checksum
  - `-9` to `-15`: raw deflate format without header or checksum
  - `16 + (9 to 15)`: gzip format with header and checksum
  - Values `32-47`: automatic header detection (zlib or gzip)
- `bufsize`: Initial size of output buffer for decompressed data (default: 16384)

**Returns:** The decompressed data as `List[UInt8]`

**Raises:** `Error` if the compressed data is invalid, corrupted, or incomplete

### decompressobj

```mojo
fn decompressobj(wbits: Int32 = MAX_WBITS) raises -> Decompress
```

Return a decompression object whose `decompress()` method takes a bytes object and returns decompressed data for a portion of the data.

The returned object also has `decompress()` and `flush()` methods, and `unused_data`, `unconsumed_tail`, and `eof` attributes. This allows for incremental decompression when decompressing very large amounts of data.

**Parameters:**
- `wbits`: Window bits parameter (same as `decompress()`)

**Returns:** A `Decompress` object for incremental decompression

**Raises:** `Error` if decompression initialization fails or invalid parameters provided

### crc32

```mojo
fn crc32(data: Span[UInt8], value: UInt32 = 0) -> UInt32
```

Computes a CRC (Cyclic Redundancy Check) checksum of data.

This computes a 32-bit checksum of data. The result is an unsigned 32-bit integer. If value is present, it is used as the starting value of the checksum; otherwise, a default value of 0 is used. Passing the value returned by a previous call allows computing a running checksum over the concatenation of several inputs.

**Parameters:**
- `data`: The data to compute the checksum for
- `value`: Starting value of the checksum (default: 0). Can be the result of a previous `crc32()` call

**Returns:** An unsigned 32-bit integer representing the CRC-32 checksum

### adler32

```mojo
fn adler32(data: Span[UInt8], value: UInt32 = 1) -> UInt32
```

Computes an Adler-32 checksum of data.

An Adler-32 checksum is almost as reliable as a CRC32 but can be computed much faster. The result is an unsigned 32-bit integer. If value is present, it is used as the starting value of the checksum; otherwise, a default value of 1 is used. Passing the value returned by a previous call allows computing a running checksum over the concatenation of several inputs.

**Parameters:**
- `data`: The data to compute the checksum for
- `value`: Starting value of the checksum (default: 1). Can be the result of a previous `adler32()` call

**Returns:** An unsigned 32-bit integer representing the Adler-32 checksum

## Streaming Objects

### Compress Object

A compression object for compressing data incrementally. Allows compression of data that cannot fit into memory all at once.

**Methods:**

#### compress()
```mojo
fn compress(mut self, data: Span[UInt8]) raises -> List[UInt8]
```

Compress data, returning a `List[UInt8]` containing compressed data for at least part of the data in data. This data should be concatenated to the output produced by any preceding calls to the `compress()` method. Some input may be kept in internal buffers for later processing.

**Parameters:**
- `data`: Data to compress

**Returns:** Compressed data as `List[UInt8]`. May be empty if input data is buffered internally

**Raises:** `Error` if compression fails or `flush()` has already been called

#### flush()
```mojo
fn flush(mut self) raises -> List[UInt8]
```

Finish the compression process and return a `List[UInt8]` containing any remaining compressed data. This method finishes the compression of any data that might remain in the internal buffers and returns the final compressed data. After calling `flush()`, the compressor object cannot be used again.

**Returns:** Final compressed data as `List[UInt8]`

**Raises:** `Error` if compression finalization fails

### Decompress Object

A decompression object for decompressing data incrementally. Allows decompression of data that cannot fit into memory all at once. Contains attributes `unused_data`, `unconsumed_tail`, and `eof` that provide information about the decompression process.

**Attributes:**

- `unused_data: List[UInt8]` - Contains any bytes past the end of the compressed data. Always empty until the entire compressed stream has been decompressed
- `unconsumed_tail: List[UInt8]` - Contains any data that was not consumed by the last `decompress()` call because it exceeded the limit on the uncompressed data
- `eof: Bool` - True if the end-of-stream marker has been reached

**Methods:**

#### decompress()
```mojo
fn decompress(mut self, data: Span[UInt8], max_length: Int = -1) raises -> List[UInt8]
```

Decompress data, returning a bytes object containing uncompressed data corresponding to at least part of the data in data. This data should be concatenated to the output produced by any preceding calls to the `decompress()` method.

**Parameters:**
- `data`: Compressed data to decompress
- `max_length`: Maximum number of bytes to return. If negative (default), there is no limit

**Returns:** Decompressed data as `List[UInt8]`. May be empty if input data is buffered internally

**Raises:** `Error` if the data is invalid, corrupted, or incomplete

#### flush()
```mojo
fn flush(mut self) raises -> List[UInt8]
```

Return a bytes object containing any remaining uncompressed data. This method is primarily used to force any remaining uncompressed data in internal buffers to be returned.

**Returns:** Any remaining decompressed data as `List[UInt8]`

**Raises:** `Error` if there are issues finalizing the decompression

## Constants

The library provides Python-compatible constants:

- **Compression Levels**: `Z_NO_COMPRESSION`, `Z_BEST_SPEED`, `Z_BEST_COMPRESSION`, `Z_DEFAULT_COMPRESSION`
- **Compression Methods**: `DEFLATED`, `Z_DEFLATED`
- **Compression Strategies**: `Z_DEFAULT_STRATEGY`, `Z_FILTERED`, `Z_HUFFMAN_ONLY`, `Z_RLE`, `Z_FIXED`
- **Flush Modes**: `Z_NO_FLUSH`, `Z_PARTIAL_FLUSH`, `Z_SYNC_FLUSH`, `Z_FULL_FLUSH`, `Z_FINISH`, `Z_BLOCK`, `Z_TREES`
- **Other**: `MAX_WBITS`, `DEF_BUF_SIZE`, `DEF_MEM_LEVEL`, `ZLIB_VERSION`, `ZLIB_RUNTIME_VERSION`

## Examples

### Basic Compression/Decompression

```mojo
import zlib

fn main() raises:
    text = "Hello, World! This is a longer text that will benefit from compression."
    data = text.as_bytes()
    
    # Compress data
    compressed = zlib.compress(data, level=6)
    print("Original size:", len(data), "Compressed size:", len(compressed))
    
    # Decompress data
    decompressed = zlib.decompress(compressed)
    print("Decompression successful:", String(bytes=decompressed))
```

### Streaming Compression

```mojo
import zlib

fn main() raises:
    # Create compressor
    compressor = zlib.compressobj(level=9)

    # Compress data in chunks
    chunk1 = compressor.compress("First chunk of data ".as_bytes())
    chunk2 = compressor.compress("Second chunk of data ".as_bytes())
    chunk3 = compressor.compress("Final chunk of data".as_bytes())
    final = compressor.flush()

    # Combine results
    compressed = chunk1 + chunk2 + chunk3 + final
    print(String(bytes=zlib.decompress(compressed)))
```

### Format-Specific Compression

```mojo
import zlib

fn main() raises:
    data = "Test data for different formats".as_bytes()

    # Raw DEFLATE format (no header/trailer)
    raw_compressed = zlib.compress(data, wbits=-15)

    # Gzip format 
    gzip_compressed = zlib.compress(data, wbits=16+15)

    # Standard zlib format (default)
    zlib_compressed = zlib.compress(data, wbits=15)
```

### Checksum Calculations

```mojo
import zlib

fn main() raises:
    data = "Data for checksum calculation".as_bytes()

    # Calculate CRC32
    crc = zlib.crc32(data)
    print("CRC32:", crc)

    # Calculate Adler32
    adler = zlib.adler32(data)
    print("Adler32:", adler)

    # Running checksums
    part1 = "First part ".as_bytes()
    part2 = "second part".as_bytes()

    crc1 = zlib.crc32(part1)
    crc_total = zlib.crc32(part2, crc1)  # Running checksum
    print("CRC32 running total:", crc_total)
```

## Performance

This library leverages the optimized zlib C library for compression operations while providing pure Mojo implementations for checksum functions.

## License

The license of this project is MIT. Check [LICENSE](LICENSE) for more details.
