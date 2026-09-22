# Image input

`detect-format`, `inspect`, and `decode` accept an octet array, binary input
stream, or pathname. A pathname is opened as a binary stream and closed when
the operation finishes.

Provided streams are read from their current position through EOF. They remain
open and are not repositioned.

`decode` returns an `image` with BGRA premultiplied pixels, width, height, and
stride. `unknown-format` and `decode-error` describe invalid image data.

```lisp
(cl-wuffs:decode #p"image.png")
(with-open-file (stream #p"image.png" :element-type '(unsigned-byte 8))
  (cl-wuffs:inspect stream))
```
