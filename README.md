# ImageProcessing

Provides higher-level image processing functionality that is commonly needed
when accepting user uploads. Supports processing with [VIPS] and
[ImageMagick]/[GraphicsMagick].

The goal of this project is to have a single place where common image
processing helper methods are maintained, instead of Paperclip, CarrierWave,
Refile, Dragonfly and ActiveStorage each implementing their own versions.

## Installation

```rb
gem "image_processing"
```

## Usage

Processing is performed through `ImageProcessing::Vips` or
`ImageProcessing::MiniMagick` modules. Both modules share the same chainable
API for defining the processing pipeline:

```rb
require "image_processing/mini_magick"

processed = ImageProcessing::MiniMagick
  .source(file)
  .resize_to_limit(400, 400)
  .convert("png")
  .call

processed #=> #<File:/var/folders/.../image_processing20180316-18446-1j247h6.png>
```

This allows easy branching when generating multiple derivatives:

```rb
require "image_processing/vips"

pipeline = ImageProcessing::Vips
  .source(file)
  .convert("png")

large  = pipeline.resize_to_limit!(800, 800)
medium = pipeline.resize_to_limit!(500, 500)
small  = pipeline.resize_to_limit!(300, 300)
```

The processing is executed on `#call` or when a processing method is called
with a bang (`!`).

```rb
processed = ImageProcessing::MiniMagick
  .convert("png")
  .resize_to_limit(400, 400)
  .call(image)

# OR

processed = ImageProcessing::MiniMagick
  .source(image) # declare source image
  .convert("png")
  .resize_to_limit(400, 400)
  .call

# OR

processed = ImageProcessing::MiniMagick
  .source(image)
  .convert("png")
  .resize_to_limit!(400, 400) # bang method
```

The source object needs to responds to `#path`, or be a String, a Pathname, or
a `Vips::Image`/`MiniMagick::Tool` object. The result of processing is a
`Tempfile` object, or a `Vips::Image`/`MiniMagick::Tool` if `:save` was set to
`false`.

```rb
pipeline = ImageProcessing::Vips.source(image)

tempfile = pipeline.call
tempfile #=> #<Tempfile ...>

tempfile = pipeline.call(save: false)
tempfile #=> #<Vips::Image ...>
```

You can continue reading the API documentation for specific modules:

* **[ImageProcessing::Vips]**
* **[ImageProcessing::MiniMagick]**

## Contributing

Test suite requires `imagemagick`, `graphicsmagick` and `libvips` to be
installed. On Mac OS you can install them with Homebrew:

```
$ brew install imagemagick graphicsmagick vips
```

Afterwards you can run tests with

```
$ rake test
```

## Credits

The `ImageProcessing::MiniMagick` functionality was extracted from
[refile-mini_magick].

## License

[MIT](LICENSE.txt)

[ImageMagick]: https://www.imagemagick.org
[GraphicsMagick]: http://www.graphicsmagick.org
[VIPS]: http://jcupitt.github.io/libvips/
[ImageProcessing::Vips]: /doc/vips.md#imageprocessingvips
[ImageProcessing::MiniMagick]: /doc/minimagick.md#imageprocessingminimagick
[refile-mini_magick]: https://github.com/refile/refile-mini_magick
