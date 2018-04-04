# ImageProcessing

Provides higher-level image processing helpers that are commonly needed
when handling image uploads.

This gem can process images with either [libvips] and [ImageMagick] libraries.
ImageMagick is a good default choice, especially if you are migrating from
another attachment gem that uses ImageMagick. Livips is a very fast alternative
that works best with JPEGs and PNGs. Support for GIFs is limited in libvips.


## Goal

The goal of this project is to have a single gem that contains all the
helper methods needed to resize and process images. Currently, existing
attachment gems (like Paperclip, CarrierWave, Refile, Dragonfly, 
ActiveStorage, and others) implement their own custom image helper methods.
But why?

Let's be honest. Image processing is a dark, mysterious art. So we want to 
combine everything bit of best practice from all of these gems into a single, 
awesome library that is constantly updated with best-practice thinking about 
how to resize and process images.


## Installation

1. Install ImageMagick and Libvips:

`$ brew install imagemagick vips`

Note: if you're not on macOS or don't want to use Homebrew, check the project
pages for ImageMagick and Libvips for other ways to install these libraries.

2. Add the gem to your Gemfile:

`gem 'image_processing', '~> 0.11'`


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

You can inspect the pipeline options at any point before executing it:

```rb
pipeline = ImageProcessing::MiniMagick
  .source(image)
  .loader(page: 1)
  .convert("png")
  .resize_to_limit(400, 400)
  .strip

pipeline.options
# => {:source=>#<File:/path/to/source.jpg>,
#     :loader=>{:page=>1},
#     :saver=>{},
#     :format=>"png",
#     :operations=>[[:resize_to_limit, [400, 400]], [:strip, []]],
#     :processor_class=>ImageProcessing::MiniMagick::Processor}
```

The source object needs to responds to `#path`, or be a String, a Pathname, or
a `Vips::Image`/`MiniMagick::Tool` object.

```rb
ImageProcessing::Vips.source(File.open("source.jpg"))
ImageProcessing::Vips.source("source.jpg")
ImageProcessing::Vips.source(Pathname.new("source.jpg"))
ImageProcessing::Vips.source(Vips::Image.new_from_file("source.jpg"))
```

By default the result of processing is a `Tempfile` object. You can save the
processing result to a specific location by passing `:destination` to `#call`,
or pass `save: false` to retrieve the raw `Vips::Image`/`MiniMagick::Tool`
object.

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

Our test suite requires `imagemagick` and `libvips` to be installed. On macOS,
you can install them with Homebrew:

```
$ brew install imagemagick vips
```

Afterwards you can run tests with

```
$ bundle exec rake test
```


## Feedback

We welcome your feedback! What would you like to see added to image_processing?
How can we improve this gem? Open an issue and let us know!


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
