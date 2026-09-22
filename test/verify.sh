#!/bin/sh
set -eu

test "$(sha256sum vendor/wuffs/wuffs-v0.3.c | cut -d ' ' -f 1)" = "73ecada234e48c85b96f3ed62a3c276fedeeca0a7b022902900ed75351516eb7"
python3 generate-bindings.py clang
git diff --exit-code -- bindings/generated.lisp
for format in BMP GIF NIE PNG TGA WBMP; do
  grep -q "WUFFS_BASE__FOURCC__${format}" src/shim.cpp
done
cmake -S . -B build
cmake --build build
CL_WUFFS_LIBRARY="$PWD/build/libcl_wuffs.so" XDG_CACHE_HOME="$PWD/.cache" \
  sbcl --non-interactive --eval '(require :asdf)' \
       --eval '(asdf:load-asd (truename "cl-wuffs.asd"))' \
       --eval '(asdf:test-system "cl-wuffs/test")'
