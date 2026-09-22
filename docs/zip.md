# ZIP archives

`open-zip` reads an archive into memory. `zip-entries` returns its entries and
`read-zip-entry` returns one entry's octets by entry or name.

```lisp
(let ((archive (cl-wuffs:open-zip #p"archive.zip")))
  (cl-wuffs:read-zip-entry archive "notes.txt"))
```

Stored and Deflate entries are supported. CRC-32 is checked on every read.
Encrypted, multi-disk, Zip64, and other compression methods signal `zip-error`.

Default limits are 10,000 entries, 64 MiB compressed and 256 MiB decompressed
per entry, and 1 GiB total decompressed size. Override them with `open-zip`'s
limit keywords when needed.
