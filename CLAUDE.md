# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

mojo-zlib is a Mojo implementation of Python's zlib module, providing compression and decompression functionality that follows the Python API. The project uses the zlib C library through FFI (Foreign Function Interface) calls.

## Additional information about Mojo
Since the Mojo language is pretty new, the Mojo repository can be found in `modular/` with a memory file at @modular/CLAUDE.md . The files in the `modular/` directory should never be updated and are only here as a reference to understand how the Mojo language works. Whenever in doubt, search the code in this directory.

Do not use print statements in the tests. They won't be seen if the tests are passing correctly.

List is auto-cast to Span when calling a function. So it's not necessary to implement a function for both Span and List. Just implementing it for Span is enough.

In docstrings, sentences to describe a function or an argument should always end with a "."

In Mojo `Byte` is an alias for `UInt8`. Prefer using `UInt8`.

In Mojo, declaring a local variable with `var` is valid. But the author prefer using implicit declaring of local variable, so the `var` is not needed. The only place it's needed is to declare struct attributes.

## Project Structure

```
src/
└── zlib/
    ├── __init__.mojo              # Main module interface
    └── _src/
        ├── __init__.mojo          # Package initialization
        ├── checksums.mojo         # CRC32 and Adler32 implementations
        ├── compression.mojo       # Compression functions and streaming
        ├── constants.mojo         # zlib constants and FFI types
        ├── decompression.mojo     # Decompression functions and streaming
        ├── utils_testing.mojo     # Testing utilities and Python interop
        └── zlib_shared_object.mojo # Dynamic library loading
```

## Build and Test Commands

- **Run tests**: `pixi run test` (equivalent to `mojo test -I ./src tests/`)
- **Format code**: `pixi run format` (equivalent to `mojo format`)
- **Build and publish**: `pixi run publish` (builds conda package and publishes to mojo-community channel)

## Release Process

The project uses GitHub Actions for automated releases and publishing to conda channels:

### Release Workflow

1. **Create a GitHub Release**: When a new release is published on GitHub, it triggers the automated build and publish workflow.

2. **Multi-platform Builds**: The release workflow (`/.github/workflows/publish.yml`) automatically builds packages for multiple platforms:
   - `linux-64` (Ubuntu latest)
   - `osx-arm64` (macOS latest) 
   - `linux-aarch64` (Ubuntu 24.04 ARM)

3. **Automated Publishing**: Each platform build:
   - Runs on the respective platform using GitHub Actions runners
   - Uses the `pixi run publish` command to build and upload packages
   - Authenticates with prefix.dev using the `PREFIX_API_KEY` secret
   - Publishes to the `mojo-community` conda channel

### Publishing Process (scripts/publish.py)

The publish script handles:
- **Recipe Generation**: Automatically generates a `recipe.yaml` from `pixi.toml` configuration
- **Package Building**: Creates conda packages using `pixi build`
- **Upload**: Uploads built packages to the mojo-community channel on prefix.dev
- **Cleanup**: Removes temporary files after successful upload

### Manual Publishing

For manual releases, you can use:
```bash
# Build and publish in one step
pixi run publish

# Or step by step:
python scripts/publish.py generate-recipe
python scripts/publish.py build-conda-package  
python scripts/publish.py publish mojo-community
```

**Note**: Manual publishing requires the `PREFIX_API_KEY` environment variable to be set for authentication with prefix.dev.

### Image Display on prefix.dev

To ensure images in the README.md appear correctly on prefix.dev, you need to use absolute URLs instead of relative paths. The current image reference in README.md:

```markdown
![mojo-zlib](docs/mojo-zlib.png)
```

Should be changed to use the absolute GitHub URL:

```markdown
![mojo-zlib](https://raw.githubusercontent.com/gabrieldemarmiesse/mojo-zlib/main/docs/mojo-zlib.png)
```

**Why this is needed:**
- prefix.dev displays the package description from the README.md file
- The publish script copies the README.md content to the conda package's `about.description` field
- prefix.dev cannot resolve relative image paths like `docs/mojo-zlib.png`
- Using absolute URLs ensures images display correctly on the package page

**Alternative approaches:**
- Host images on a CDN or image hosting service
- Use GitHub's raw content URLs (recommended for open source projects)
- Include images in the conda package itself (not recommended for web display)

## Key Implementation Details

### FFI Integration
The project uses FFI to call zlib C library functions. Key patterns:
- All zlib functions are loaded dynamically via `get_zlib_dl_handle()`
- C structures like `ZStream` are defined in `constants.mojo`
- Error handling uses `log_zlib_result()` for consistent error messages

### Function Signatures
Functions follow Python's zlib API:
- `compress(data, level=-1, wbits=15)` - Compress data
- `decompress(data, wbits=15, bufsize=16384)` - Decompress data
- `compressobj()` / `decompressobj()` - Streaming compression/decompression
- `crc32(data, value=0)` / `adler32(data, value=1)` - Checksum functions

### Window Bits Parameter
The `wbits` parameter controls compression format:
- Positive values (9-15): zlib format with header and trailer
- Negative values (-9 to -15): raw deflate format  
- Values 25-31: gzip format

### Python-Compatible Decompression Object Attributes

The `Decompress` struct provides Python-compatible attributes via getter functions:
- `get_unused_data() -> List[UInt8]` - Returns data that was not consumed by decompression (after end-of-stream)
- `get_unconsumed_tail() -> List[UInt8]` - Returns input data that has not yet been consumed by decompression  
- `get_eof() -> Bool` - Returns True if the end-of-stream marker has been reached

**Usage Example:**
```mojo
var decompressor = zlib.decompressobj()
var result = decompressor.decompress(compressed_data_with_extra)

# Check if we reached end of stream
if decompressor.get_eof():
    # Any extra data after the compressed stream
    var unused = decompressor.get_unused_data()
    print("Found", len(unused), "bytes of unused data")

# Check what input data hasn't been processed yet
var unconsumed = decompressor.get_unconsumed_tail()
```

## String to Bytes Conversion

When converting strings to bytes, use the `String.as_bytes()` method instead of manually iterating:

```mojo
# Preferred - clean and efficient
var text = "Hello, World!"
var bytes = text.as_bytes()

# Avoid - manual conversion
var manual_bytes = List[UInt8]()
for i in range(len(text)):
    manual_bytes.append(ord(text[i]))
```

## Python Interoperability in Tests

You can call Python functions directly from Mojo test files to ensure compatibility. Use this pattern for testing against Python's standard library:

```mojo
from python import Python
from zlib._src.utils_testing import to_py_bytes, assert_lists_are_equal, to_mojo_bytes

def test_function_python_compatibility():
    """Test that our function matches Python's behavior."""
    # Import Python module
    py_zlib = Python.import_module("zlib")
    
    # Test data
    test_data = "Hello, World!".as_bytes()
    
    # Call Mojo function
    mojo_result = our_function(test_data)
    
    # Call Python function
    py_data_bytes = to_py_bytes(test_data)
    py_result = py_zlib.function_name(py_data_bytes)
    
    # Convert Python result to Mojo for comparison
    py_result_list = to_mojo_bytes(py_result)
    
    # Compare results
    assert_lists_are_equal(mojo_result, py_result_list)
```

Use `to_py_bytes()` utility function from `zlib._src.utils_testing` to convert Mojo bytes to Python bytes objects.

## Additional Utility Functions in `utils_testing.mojo`

**Data Conversion:**
- `to_py_bytes(data: Span[UInt8]) -> PythonObject` - Convert Mojo bytes to Python bytes
- `to_mojo_bytes(some_data: PythonObject) -> List[UInt8]` - Convert Python bytes to Mojo bytes  
- `to_mojo_string(some_data: PythonObject) -> String` - Convert Python bytes to Mojo String

**Testing Utilities:**
- `assert_lists_are_equal(list1: List[UInt8], list2: List[UInt8], message: String)` - Compare two byte lists with detailed error messages
- `test_mojo_vs_python_decompress(test_data: Span[UInt8], wbits: Int = 15, bufsize: Int = 16384, message: String)` - Helper to test Mojo vs Python decompress compatibility

**Usage Example:**
```mojo
# Simple comparison
var result1 = function1(data)
var result2 = function2(data) 
assert_lists_are_equal(result1, result2, "Functions should produce same result")

# Python compatibility test
test_mojo_vs_python_decompress(
    test_data.as_bytes(),
    wbits=31,
    message="gzip format should match Python"
)
```

## Testing Error Conditions

For testing error conditions and exceptions, use Mojo's `assert_raises` as a context manager:

```mojo
from testing import assert_raises

# Test that a function raises an error
def test_invalid_input():
    var invalid_data = List[UInt8](1, 2, 3, 4, 5)
    
    with assert_raises():
        _ = zlib.decompress(invalid_data)

# Test that an error contains specific text
def test_specific_error():
    with assert_raises(contains="File not found"):
        _ = zip_file.read("nonexistent.txt")
```

**Important**: Use `assert_raises()` as a context manager with `with` statement, not as a function call with lambda. The context manager pattern is the correct and idiomatic way to test exceptions in Mojo.

## Code Style Guidelines

### Function Parameters
- Use positional-only parameters (`/`) for data arguments to match Python's API
- Follow Python's parameter order and defaults exactly
- Document all parameters in docstrings with proper descriptions ending in "."

### Error Handling
- Use `log_zlib_result()` for consistent zlib error handling
- Raise `Error()` with descriptive messages for invalid inputs
- Test error conditions thoroughly using `assert_raises()`

### Testing Patterns
- **Python Compatibility**: Always test against Python's zlib for identical behavior
- **Random Data**: Use seeded random data for reproducible tests
- **Edge Cases**: Test empty data, large data, and boundary conditions
- **Format Variations**: Test different wbits values (zlib, raw deflate, gzip)
- **Streaming**: Test both one-shot and streaming APIs

### Memory Management
- Use `UnsafePointer` for FFI integration with proper cleanup
- Initialize C structures with `memset_zero()` before use
- Always call `inflateEnd()` / `deflateEnd()` to free zlib resources

### Import Organization
```mojo
# Standard library imports first
from sys import ffi
from memory import memset_zero, UnsafePointer

# Local imports second
from .constants import ZStream, Z_OK, ...
from .zlib_shared_object import get_zlib_dl_handle
```

## LLM-friendly Documentation of Mojo, don't hesistate to use it!

- Docs index: <https://docs.modular.com/llms.txt>
- Mojo API docs: <https://docs.modular.com/llms-mojo.txt>
- Python API docs: <https://docs.modular.com/llms-python.txt>
- Comprehensive docs: <https://docs.modular.com/llms-full.txt>


## Tips

the following lists all tests: `pixi run mojo test -I ./src --collect-only tests/`.
The output looks like this:
```
</projects/open_source/mojo-zlib/tests>
  </projects/open_source/mojo-zlib/tests/test_adler32.mojo>
    </projects/open_source/mojo-zlib/tests/test_adler32.mojo::test_adler32_basic()>
    </projects/open_source/mojo-zlib/tests/test_adler32.mojo::test_adler32_with_starting_value()>
    </projects/open_source/mojo-zlib/tests/test_adler32.mojo::test_adler32_concatenation()>
    </projects/open_source/mojo-zlib/tests/test_adler32.mojo::test_adler32_return_type()>
    </projects/open_source/mojo-zlib/tests/test_adler32.mojo::test_adler32_binary_data()>
    </projects/open_source/mojo-zlib/tests/test_adler32.mojo::test_adler32_repeated_calls()>
  </projects/open_source/mojo-zlib/tests/test_adler32_python_compatibility.mojo>
    </projects/open_source/mojo-zlib/tests/test_adler32_python_compatibility.mojo::test_adler32_empty_data_python_compatibility()>
    </projects/open_source/mojo-zlib/tests/test_adler32_python_compatibility.mojo::test_adler32_hello_python_compatibility()>
```

To run one single unit test, run `pixi run mojo test -I ./src 'tests/test_adler32.mojo::test_adler32_basic()'`.