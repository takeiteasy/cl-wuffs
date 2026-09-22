# Checksums

`adler32` and `crc32` accept octet arrays and return unsigned 32-bit checksums.
`crc32` uses the IEEE variant.

```lisp
(cl-wuffs:crc32 #(49 50 51 52 53 54 55 56 57))
```

Use a hasher for incremental input.

```lisp
(let ((hasher (cl-wuffs:make-hasher :crc32)))
  (unwind-protect
       (progn
         (cl-wuffs:hash-chunk hasher first-chunk)
         (cl-wuffs:hash-chunk hasher second-chunk)
         (cl-wuffs:finish-hasher hasher))
    (cl-wuffs:close-hasher hasher)))
```

Supported algorithms are `:adler32` and `:crc32`. A hasher is no longer usable
after `finish-hasher` or `close-hasher`; invalid use signals `hash-error`.
