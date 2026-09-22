# API

`detect-format`, `inspect`, and `decode` accept an octet vector. They inspect
the bytes directly and never use a filename or extension.

`decode` returns an `image` with BGRA premultiplied pixel octets, width,
height, and stride. Animated inputs return the first composited frame.

`unknown-format` and `decode-error` are typed conditions. `adler32` is an
explicit hash operation because hash inputs do not have a file signature.

The generated compression systems currently register Wuffs' v0.3 codec layout.
Their streaming decompression API is tracked separately.
