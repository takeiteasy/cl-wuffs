# Animation decoding

`decode-animation` accepts an octet array, binary stream, or pathname and
returns every composited frame. Each `animation-frame` contains an `image` and
its `duration-milliseconds`.

`animation-loop-count` is `:infinite` for looping animations with an unlimited
loop count. Static images produce one frame with a zero duration.

```lisp
(let ((animation (cl-wuffs:decode-animation #p"animated.gif")))
  (cl-wuffs:animation-frames animation))
```
