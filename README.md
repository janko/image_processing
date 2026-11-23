# ImageProcessing

Provides higher-level image processing helpers that are commonly needed
when handling image uploads.

This gem can process images with [ImageMagick] or [libvips]. ImageMagick is a
good default choice, especially if you are migrating from another gem or library
that uses ImageMagick. Libvips is a newer library that can process images [very
rapidly][libvips performance] (often multiple times faster than ImageMagick).


## Goal

The goal of this project is to have a single gem that contains all the
helper methods needed to resize and process images.

Currently, existing attachment gems (like Paperclip, CarrierWave, Refile,
Dragonfly, Active Storage, and others) implement their own custom image
helper methods. But why? That's not very DRY, is it?

Let's be honest. Image processing is a dark, mysterious art. So we want to
combine every great idea from all of these separate gems into a single awesome
library that is constantly updated with best-practice thinking about
how to resize and process images.


## Installation

1. Install ImageMagick and/or libvips:

   On macOS:

   ```sh
   $ brew install imagemagick # if using ImageMagick
   $ brew install vips # if using libvips
   ```

   On Debian/Ubuntu:

   ```sh
   $ sudo apt install imagemagick # if using ImageMagick
   $ sudo apt install libvips # if using libvips
   ```

2. Add the gem(s) to your Gemfile:

   ```rb
   gem "image_processing", "~> 2.0"
   gem "mini_magick", "~> 5.0" # if using ImageMagick
   gem "ruby-vips", "~> 2.0" # if using libvips
   ```

## Usage

Processing is performed through **[`ImageProcessing::Vips`]** or
**[`ImageProcessing::MiniMagick`]** modules. Both modules share the same
chainable API for defining the processing pipeline:

```rb
require "image_processing/mini_magick"

processed = ImageProcessing::MiniMagick
  .source(file)
  .resize_to_limit(400, 400)
  .convert("png")
  .call

processed #=> #<Tempfile:/var/folders/.../image_processing20180316-18446-1j247h6.png>
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
#     :processor=>ImageProcessing::MiniMagick::Processor}
```

The source object needs to respond to `#path`, or be a String, a Pathname, or
a `Vips::Image`/`MiniMagick::Tool` object. If no source is given,
`ImageProcessing::Error` is raised. Note that the processed file is always saved
to a new location, in-place processing is not supported.

```rb
ImageProcessing::Vips.source(File.open("source.jpg"))
ImageProcessing::Vips.source("source.jpg")
ImageProcessing::Vips.source(Pathname.new("source.jpg"))
ImageProcessing::Vips.source(Vips::Image.new_from_file("source.jpg"))
```

With `ImageProcessing::Vips`, the source can also be an IO object that responds
to `#read(length)`, such as a `StringIO`, a `Down::ChunkedIO` or a Shrine
uploaded file. The IO object is streamed into libvips while processing, so it
doesn't need to be written to disk first.

```rb
ImageProcessing::Vips.source(StringIO.new(image_data))
ImageProcessing::Vips.source(Down.open("https://example.com/image.jpg"))
```

The IO object is read in the calling thread, while the image is processed in a
separate thread, so a `#custom` block won't see thread-local or fiber-local
state. On ruby-vips 2.3.0 and older, use libvips operations inside a `#custom`
block rather than methods that read pixels directly, such as
`Vips::Image#to_a`, `#write_to_memory` or `#copy_memory`: those versions hold
the GVL while running them, so they would deadlock waiting for data from the IO
object. The same applies to `Vips::Region#fetch` on all ruby-vips versions so
far. With `save: false`, the IO object is read into memory
upfront, as libvips reads pixels only after the image is returned.

When `#call` is called without options, the result of processing is a
`Tempfile` object. You can save the processing result to a specific location by
passing `:destination` to `#call`, or pass `save: false` to retrieve the raw
`Vips::Image`/`MiniMagick::Tool` object.

```rb
pipeline = ImageProcessing::Vips.source(image)

pipeline.call #=> #<Tempfile ...>
pipeline.call(save: false) #=> #<Vips::Image ...>
pipeline.call(destination: "/path/to/destination.jpg")
```

When saving to a tempfile, the output format is the one passed to `#convert`,
falling back to the extension of the source file, and finally to JPEG. When
saving to a `:destination` path, the format is determined by the path's
extension; if the path has no extension (e.g. `/dev/fd/N`), the format passed
to `#convert` is used.

If processing fails while saving to a `:destination` path that didn't exist
before, the partially written file is deleted before the error is re-raised.

You can continue reading the API documentation for specific modules:

* **[`ImageProcessing::Vips`]**
* **[`ImageProcessing::MiniMagick`]**

See the **[wiki]** for additional "How To" guides for common scenarios. The wiki
is publicly editable, so you're encouraged to add your own guides.

## Applying operations from a hash

Instead of chaining methods, you can pass operations as a hash to `#apply`,
which is handy when the processing steps are stored as data (e.g. Active
Storage variants). Hash keys are the builder methods to call, and values are
the arguments: a single argument, an array of arguments, a hash of keyword
arguments, or `true`/`nil` for no arguments.

```rb
ImageProcessing::Vips
  .source(image)
  .apply(resize_to_limit: [400, 400], sharpen: true, convert: "png")
  .call

# equivalent to

ImageProcessing::Vips
  .source(image)
  .resize_to_limit(400, 400)
  .sharpen
  .convert("png")
  .call
```

To call the same method more than once, pass an array of pairs instead:

```rb
ImageProcessing::Vips
  .apply([[:rotate, 90], [:rotate, 90]])
```

## Instrumentation

You can register an `#instrumenter` block for a given pipeline, which will wrap
the pipeline execution, allowing you to record performance metrics. The block
receives the pipeline options as keyword arguments (including `:destination`
when one was given), and the pipeline must be executed by calling the yielded
block.

```rb
pipeline = ImageProcessing::Vips.instrumenter do |**options, &processing|
  options[:source]     #=> #<File:...>
  options[:loader]     #=> { fail: true }
  options[:saver]      #=> { quality: 85 }
  options[:format]     #=> "png"
  options[:operations] #=> [[:resize_to_limit, [500, 500]], [:flip, [:horizontal]]]
  options[:processor]  #=> ImageProcessing::Vips::Processor

  ActiveSupport::Notifications.instrument("process.image_processing", **options) do
    processing.call # calls the pipeline
  end
end

pipeline
  .source(image)
  .loader(fail: true)
  .saver(quality: 85)
  .convert("png")
  .resize_to_limit(500, 500)
  .flip(:horizontal)
  .call # calls instrumenter
```

## Contributing

Our test suite requires both `imagemagick` and `libvips` libraries to be installed. Afterwards you can run tests with:

```sh
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

[libvips]: https://www.libvips.org/
[ImageMagick]: https://imagemagick.org
[`ImageProcessing::Vips`]: doc/vips.md#readme
[`ImageProcessing::MiniMagick`]: doc/minimagick.md#readme
[refile-mini_magick]: https://github.com/refile/refile-mini_magick
[wiki]: https://github.com/janko/image_processing/wiki
[HTTP.rb]: https://github.com/httprb/http
[libvips performance]: https://github.com/libvips/libvips/wiki/Speed-and-memory-use
