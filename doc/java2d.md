# ImageProcessing::Java2D

`ImageProcessing::Java2D` is a JRuby image processor implemented with the JDK's
ImageIO and Java2D APIs. It has no native library or additional gem dependency.
MiniMagick and Vips remain available on JRuby and are not replaced automatically.

## Usage

```rb
require "image_processing/java2d"

processed = ImageProcessing::Java2D
  .source(image)
  .resize_to_limit(400, 400)
  .convert("png")
  .call
```

In Rails, select it with `config.active_storage.variant_processor = :java2d`.
The canonical Ruby API remains `ImageProcessing::Java2D`.

The processor implements `resize_to_limit`, `resize_to_fit`, `resize_to_fill`,
`resize_and_pad`, `resize_to_cover`, `crop`, `rotate`, `flip`, `composite`, and
`strip`. JPEG EXIF orientation is applied on load by default; pass
`loader(auto_orient: false)` to retain the stored orientation.

The Java2D-specific operation keywords are `gravity` on `resize_to_fill`,
`background` and `gravity` on `resize_and_pad`, `background` on `rotate`, and
`mode`, `gravity`, and `offset` on `composite`. Other operation keywords are
rejected instead of being silently ignored.

Image formats are limited to the ImageIO readers and writers installed in the
JVM. Standard JDKs include JPEG, PNG, GIF, BMP, and WBMP. The `saver` options
are `quality` (either `0.0..1.0` or `0..100`), `saver` for an explicit ImageIO
format name, and `background` for flattening transparent images to JPEG.

`composite` supports the `over`, `src`, `clear`, and `dest-over` modes. Java2D
does not provide equivalents for every ImageMagick or libvips operation; use
`custom` to work directly with the `java.awt.image.BufferedImage` accumulator.
