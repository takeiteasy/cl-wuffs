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

See [image input](docs/image-input.md), [animation decoding](docs/animation.md),
[ZIP archives](docs/zip.md), [checksums](docs/checksums.md), and [streaming
decompression](docs/decompression.md). The bundled native shim
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

```text
MIT License

Copyright (c) 2026 George Watson

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
