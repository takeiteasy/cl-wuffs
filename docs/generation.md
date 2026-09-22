# Generated bindings

`vendor/wuffs/wuffs-v0.3.c` is the pinned Wuffs 0.3.0 release. Its SHA-256 is
`73ecada234e48c85b96f3ed62a3c276fedeeca0a7b022902900ed75351516eb7`.

Regenerate CFFI declarations after changing `include/cl_wuffs.h`:

```sh
tools/generate-bindings.py /opt/homebrew/opt/llvm/bin/clang
```

The generator parses exported structs and every `cl_wuffs_*` declaration from
Clang's JSON AST, then writes `lisp/bindings/generated.lisp`. Runtime helpers
stay in `lisp/bindings/runtime.lisp`.
