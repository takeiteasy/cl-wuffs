# Streaming decompression

Use a decompressor for `:bzip2`, `:deflate`, `:gzip`, `:lzw`, or `:zlib`.
`decompress-chunk` returns output available after each input chunk.
`finish-decompressor` returns remaining output and validates the end of input.
Call `close-decompressor` when finished.

```lisp
(let ((decoder (cl-wuffs:make-decompressor :gzip)))
  (unwind-protect
       (progn
         (cl-wuffs:decompress-chunk decoder chunk)
         (cl-wuffs:finish-decompressor decoder))
    (cl-wuffs:close-decompressor decoder)))
```

LZW requires a literal width: `(make-decompressor :lzw :literal-width 8)`.
Malformed, truncated, or invalid decoder use signals `decompression-error`.
