# cl-wuffs

Common Lisp bindings for [Wuffs](https://github.com/google/wuffs), a safe and
fast decoder library.

## Installation

cl-wuffs requires [CFFI](https://common-lisp.net/project/cffi/), CMake, and a
C++17 compiler. Build the native library:

```sh
cmake -S . -B build
cmake --build build
```

Set `CL_WUFFS_LIBRARY` to the resulting library before loading the ASDF system:

```sh
export CL_WUFFS_LIBRARY="$PWD/build/libcl_wuffs.dylib"
```

```lisp
(asdf:load-system "cl-wuffs")
```

## API

See [image input](docs/image-input.md), [checksums](docs/checksums.md), and
[streaming decompression](docs/decompression.md). The bundled native shim
decodes BMP, GIF, NIE, PNG, TGA, and WBMP images.

## Generated bindings

`vendor/wuffs/wuffs-v0.3.c` is Wuffs 0.3.0. Its SHA-256 is
`73ecada234e48c85b96f3ed62a3c276fedeeca0a7b022902900ed75351516eb7`.

Regenerate the CFFI declarations after changing `src/cl_wuffs.h`:

```sh
generate-bindings.py /opt/homebrew/opt/llvm/bin/clang
```

The generator writes `bindings/generated.lisp`; runtime helpers live in
`bindings/runtime.lisp`.

## Tests

Build the native library, set `CL_WUFFS_LIBRARY`, then run the FiveAM suite:

```lisp
(asdf:test-system "cl-wuffs/test")
```

## License

MIT. See [LICENSE](LICENSE).
