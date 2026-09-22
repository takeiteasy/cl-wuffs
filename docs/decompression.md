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

## Stream-to-stream decompression

`decompress-stream` reads a binary input stream and writes decoded octets to a
binary output stream. It uses an 8 KiB buffer by default; pass `:buffer-size`
to change it.

```lisp
(with-open-file (input #p"archive.gz" :element-type '(unsigned-byte 8))
  (with-open-file (output #p"archive" :direction :output :if-exists :supersede
                   :element-type '(unsigned-byte 8))
    (cl-wuffs:decompress-stream :gzip input output)))
```

It does not close either stream. If decompression fails, it signals
`decompression-error` and leaves bytes already written to the output stream.
