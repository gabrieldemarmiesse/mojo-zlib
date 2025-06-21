from python import PythonObject, Python
import zlib


def to_py_bytes(data: String) -> PythonObject:
    return to_py_bytes(data.as_bytes())


def to_py_bytes(data: Span[UInt8]) -> PythonObject:
    """Convert Mojo String or Span[UInt8] to Python bytes."""
    py_builtins = Python.import_module("builtins")

    result_as_list = py_builtins.list()
    for byte in data:
        result_as_list.append(byte)
    return py_builtins.bytes(result_as_list)


fn to_mojo_bytes(some_data: PythonObject) raises -> List[UInt8]:
    result = List[UInt8]()
    for byte in some_data:
        result.append(UInt8(Int(byte)))
    return result


fn to_mojo_string(some_data: PythonObject) raises -> String:
    mojo_bytes = to_mojo_bytes(some_data)
    return String.from_bytes(mojo_bytes)


fn assert_lists_are_equal(
    list1: Span[UInt8],
    list2: Span[UInt8],
    message: String = "Lists should be equal",
) raises -> None:
    if len(list1) != len(list2):
        raise Error(message + ": Lengths differ")
    for i in range(len(list1)):
        if list1[i] != list2[i]:
            raise Error(
                message
                + ": Elements at index "
                + String(i)
                + " differ ("
                + String(list1[i])
                + " != "
                + String(list2[i])
                + ")"
            )


def test_mojo_vs_python_decompress(
    test_data: Span[UInt8],
    wbits: Int = 15,
    bufsize: Int = 16384,
    message: String = "Mojo vs Python decompress should match",
):
    """Helper function to test Mojo decompress vs Python decompress."""
    try:
        py_zlib = Python.import_module("zlib")

        # Compress with Python
        py_data_bytes = to_py_bytes(test_data)
        py_compressed = py_zlib.compress(py_data_bytes, wbits=wbits)

        # Convert to Mojo and decompress with Mojo
        mojo_compressed = to_mojo_bytes(py_compressed)

        # Import the Mojo decompress function

        mojo_result = zlib.decompress(
            mojo_compressed, wbits=wbits, bufsize=bufsize
        )

        # Decompress with Python
        py_result = py_zlib.decompress(
            py_compressed, wbits=wbits, bufsize=bufsize
        )
        py_result_mojo = to_mojo_bytes(py_result)

        # Compare results
        assert_lists_are_equal(mojo_result, py_result_mojo, message)
    except e:
        print("Error in test_mojo_vs_python_decompress:", e)
        raise e


def compress_string_with_python(
    text: StringSlice, wbits: Int = 15
) -> List[UInt8]:
    return compress_binary_data_with_python(text.as_bytes(), wbits=wbits)


def compress_binary_data_with_python(
    data: Span[UInt8], wbits: Int = 15
) -> List[UInt8]:
    py_zlib = Python.import_module("zlib")
    py_data_bytes = to_py_bytes(data)
    py_compressed = py_zlib.compress(py_data_bytes, wbits=wbits)
    return to_mojo_bytes(py_compressed)
