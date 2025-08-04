import os
from sys import ffi
from .constants import USE_ZLIB


fn get_libz_path() raises -> String:
    """Get the path to libz.so, preferring conda environment if available."""
    @parameter
    if USE_ZLIB:
        var conda_prefix = os.getenv("CONDA_PREFIX", "")
        if conda_prefix == "":
            raise Error(
                "CONDA_PREFIX is not set. Did you forget to activate the"
                " environment?"
            )
        return conda_prefix + "/lib/libz.so"
    else:
        raise Error("get_libz_path() not available in native Mojo mode")


fn get_zlib_dl_handle() raises -> ffi.DLHandle:
    """Get the zlib shared library handle."""
    @parameter
    if USE_ZLIB:
        var libz_path = get_libz_path()
        return ffi.DLHandle(libz_path)
    else:
        raise Error("get_zlib_dl_handle() not available in native Mojo mode")
