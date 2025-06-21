# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Additional information about Mojo
Since the Mojo language is pretty new, the Mojo repository can be found in `modular/` with a memory file at @modular/CLAUDE.md . The files in the `modular/` directory should never be updated and are only here as a reference to understand how the Mojo language works. Whenever in doubt, search the code in this directory.

Do not use print statements in the tests. They won't be seen if the tests are passing correctly.

The reference implementation in python can be found in `zipfile/reference.py`.
List is auto-cast to Span when calling a function. So it's not necessary to implement a function for both Span and List. Just implementing it for Span is enough.

In docstrings, sentences to describle a function or an argument should always end with a "."

In Mojo `Byte` is an alias for `UInt8`.

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

Use `to_py_bytes()` utility function from `zipfile.utils_testing` to convert Mojo bytes to Python bytes objects.

## Additional Utility Functions in `utils_testing.mojo`

**Data Conversion:**
- `to_py_bytes(data: Span[Byte]) -> PythonObject` - Convert Mojo bytes to Python bytes
- `to_mojo_bytes(some_data: PythonObject) -> List[Byte]` - Convert Python bytes to Mojo bytes  
- `to_mojo_string(some_data: PythonObject) -> String` - Convert Python bytes to Mojo String

**Testing Utilities:**
- `assert_lists_are_equal(list1: List[Byte], list2: List[Byte], message: String)` - Compare two byte lists with detailed error messages
- `test_mojo_vs_python_decompress(test_data: Span[Byte], wbits: Int = 15, bufsize: Int = 16384, message: String)` - Helper to test Mojo vs Python decompress compatibility

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
