# Installation

cl-wuffs requires CFFI, CMake, and a C++17 compiler.

Build the native library:

```sh
cmake -S . -B build
cmake --build build
```

Set `CL_WUFFS_LIBRARY` to the built library before loading `cl-wuffs` with
ASDF. The root system loads all generated format and group systems.

```sh
export CL_WUFFS_LIBRARY="$PWD/build/libcl_wuffs.dylib"
```
