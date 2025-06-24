import os
from sys import ffi


fn get_libz_path() raises -> String:
    """Get the path to libz.so, preferring conda environment if available."""
    var conda_prefix = os.getenv("CONDA_PREFIX", "")
    if conda_prefix == "":
        raise Error(
            "CONDA_PREFIX is not set. Did you forget to activate the"
            " environment?"
        )
    return conda_prefix + "/lib/libz.so"


fn get_zlib_dl_handle() raises -> ffi.DLHandle:
    """Get the zlib shared library handle."""
    var libz_path = get_libz_path()
    return ffi.DLHandle(libz_path)
