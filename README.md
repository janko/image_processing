# ImageProcessing

Provides higher-level image processing functionality that is commonly needed
when accepting user uploads. Supports processing with [libvips] and [ImageMagick].

The goal of this project is to have a single place where common image
processing helper methods are maintained, instead of Paperclip, CarrierWave,
Refile, Dragonfly and ActiveStorage each implementing their own versions.

## Installation

```rb
gem "image_processing", "~> 0.11"
```

## Usage

Processing is performed through [`ImageProcessing::Vips`] or
[`ImageProcessing::MiniMagick`] modules. Both modules share the same chainable
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
a `Vips::Image`/`MiniMagick::Tool` object.

```rb
ImageProcessing::Vips.source(File.open("source.jpg"))
ImageProcessing::Vips.source("source.jpg")
ImageProcessing::Vips.source(Pathname.new("source.jpg"))
ImageProcessing::Vips.source(Vips::Image.new_from_file("source.jpg"))
```

Without any call options the result of processing is a newly created `Tempfile`
object. You can save processing result to a specific location by passing
`:destination` to `#call`. You can also pass `save: false` to `#call` to
retrieve the raw `Vips::Image`/`MiniMagick::Tool` object.

```rb
pipeline = ImageProcessing::Vips.source(image)

pipeline.call #=> #<Tempfile ...>
pipeline.call(save: false) #=> #<Vips::Image ...>
pipeline.call(destination: "/path/to/destination")
```

You can continue reading the API documentation for specific modules:

* **[`ImageProcessing::Vips`]**
* **[`ImageProcessing::MiniMagick`]**

See the **[wiki]** for additional "How To" guides for common scenarios.

## Contributing

Test suite requires `imagemagick` and `libvips` to be installed. On Mac OS you
can install them with Homebrew:

```
$ brew install imagemagick vips
```

Afterwards you can run tests with

```
$ bundle exec rake test
```

## Credits

The `ImageProcessing::MiniMagick` functionality was extracted from
[refile-mini_magick]. The chainable interface was heavily inspired by
[HTTP.rb].

## License

[MIT](LICENSE.txt)

[libvips]: http://jcupitt.github.io/libvips/
[ImageMagick]: https://www.imagemagick.org
[`ImageProcessing::Vips`]: /doc/vips.md#imageprocessingvips
[`ImageProcessing::MiniMagick`]: /doc/minimagick.md#imageprocessingminimagick
[refile-mini_magick]: https://github.com/refile/refile-mini_magick
[wiki]: https://github.com/janko-m/image_processing/wiki
[HTTP.rb]: https://github.com/httprb/http
