# ImageProcessing::MiniMagick

The `ImageProcessing::MiniMagick` module contains processing methods that use
the [MiniMagick] gem (which is installed with the image_processing gem).

## Contents

* [Installation](#installation)
* [Usage](#usage)
  * [ImageMagick](#imagemagick)
  * [GraphicsMagick](#graphicsmagick)
* [Methods](#methods)
  * [`.valid_image?`](#valid_image)
  * [`#resize_to_limit`](#resize_to_limit)
  * [`#resize_to_fit`](#resize_to_fit)
  * [`#resize_to_fill`](#resize_to_fill)
  * [`#resize_and_pad`](#resize_and_pad)
  * [`#crop`](#crop)
  * [`#rotate`](#rotate)
  * [`#composite`](#composite)
  * [`#convert`](#convert)
  * [`#define`](#define)
  * [`#method_missing`](#method_missing)
  * [`#custom`](#custom)
  * [`#append`](#append)
  * [`#loader`](#loader)
  * [`#saver`](#saver)
  * [`#limits`](#limits)
  * [`#apply`](#apply)
* [Sharpening](#sharpening)

## Installation

You will need to install [ImageMagick]/[GraphicsMagick] before using this
module:

```sh
$ brew install imagemagick
# or
$ brew install graphicsmagick
```

If you're using something other than Homebrew, see the [installation
instructions] for more details.

## Usage

### ImageMagick

```rb
require "image_processing/mini_magick"

processed = ImageProcessing::MiniMagick
  .source(image)
  .resize_to_limit(400, 400)
  .strip
  .call

processed #=> #<Tempfile:/var/folders/.../image_processing20180316-18446-1j247h6.png>
```

### GraphicsMagick

The MiniMagick gem supports [GraphicsMagick] as well, you just need to specify
that you want to use it:

```rb
require "image_processing/mini_magick"

MiniMagick.cli = :graphicsmagick

processed = ImageProcessing::MiniMagick
  .source(image)
  .resize_to_limit(400, 400)
  .strip
  .call # will use `gm convert` instead of `convert`

processed #=> #<Tempfile:/var/folders/.../image_processing20180316-18446-1j247h6.png>
```

## Methods

#### `.valid_image?`

Tries to recompress the image, and returns `true` if no exception was raised,
otherwise returns `false`.

```rb
ImageProcessing::MiniMagick.valid_image?(normal_image)  #=> true
ImageProcessing::MiniMagick.valid_image?(invalid_image) #=> false
```

#### `#resize_to_limit`

Downsizes the image to fit within the specified dimensions while retaining the
original aspect ratio. Will only resize the image if it's larger than the
specified dimensions. See [this article][fit] for more details.

```rb
pipeline = ImageProcessing::MiniMagick.source(image) # 600x800

result = pipeline.resize_to_limit!(400, 400)

MiniMagick::Image.new(result.path).dimensions #=> [300, 400]
```

It's possible to omit one dimension, in which case the image will be resized
only by the provided dimension.

```rb
pipeline.resize_to_limit!(400, nil)
# or
pipeline.resize_to_limit!(nil, 400)
```

#### `#resize_to_fit`

Resizes the image to fit within the specified dimensions while retaining the
original aspect ratio. Will downsize the image if it's larger than the
specified dimensions or upsize if it's smaller. See [this article][fit] for
more details.

```rb
pipeline = ImageProcessing::MiniMagick.source(image) # 600x800

result = pipeline.resize_to_fit!(400, 400)

MiniMagick::Image.new(result.path).dimensions #=> [300, 400]
```

It's possible to omit one dimension, in which case the image will be resized
only by the provided dimension.

```rb
pipeline.resize_to_fit!(400, nil)
# or
pipeline.resize_to_fit!(nil, 400)
```

#### `#resize_to_fill`

Resizes the image to fill the specified dimensions while retaining the original
aspect ratio. If necessary, will crop the image in the larger dimension. See
[this article][fill] for more details.

```rb
pipeline = ImageProcessing::MiniMagick.source(image) # 600x800

result = pipeline.resize_to_fill!(400, 400)

MiniMagick.new(result.path).dimensions #=> [400, 400]
```

You can specify the [direction] of the image via the `:gravity` option
(defaults to `"Center"`)

```rb
pipeline.resize_to_fill!(400, 400, gravity: "north-west")
```

#### `#resize_and_pad`

Resizes the image to fit within the specified dimensions while retaining the
original aspect ratio. If necessary, will pad the remaining area with the given
color. See [this article][pad] for more details.

```rb
pipeline = ImageProcessing::MiniMagick.source(image) # 600x800

result = pipeline.resize_and_pad!(400, 400)

MiniMagick::Image.new(result.path).dimensions #=> [400, 400]
```

It accepts `:background` for specifying the background [color] that will be
used for padding (defaults to transparent/white).

```rb
pipeline.resize_and_pad!(400, 400, background: :transparent)        # default
pipeline.resize_and_pad!(400, 400, background: [65, 105, 225])      # RGB value
pipeline.resize_and_pad!(400, 400, background: [65, 105, 225, 1.0]) # RGBA value
pipeline.resize_and_pad!(400, 400, background: "...")               # any supported ImageMagick color value
```

It accepts `:gravity` for specifying the [gravity] to apply while cropping
(defaults to `"Center"`).

```rb
pipeline.resize_and_pad!(400, 400, gravity: "north-west")
```

#### `#crop`

Extracts an area from an image. The first two arguments are left & top edges of
area to extract, while the last two arguments are the width & height of area to
extract:

```rb
ImageProcessing::MiniMagick
  .crop(20, 50, 300, 300) # extracts 300x300 area with top-left edge 20,50
```

You can also specify an ImageMagick geometry directly:

```rb
ImageProcessing::MiniMagick
  .crop("300x300+20+50") # extracts 300x300 area with top-left edge 20,50
```

#### `#rotate`

Rotates the image by the specified angle. Accepts any value that [`-rotate`]
accepts.

```rb
ImageProcessing::MiniMagick
  .rotate(90)
  # ...
```

For degrees that are not a multiple of 90, you can also specify a background
[color] for the empty triangles in the corners, left over from rotating the
image.

```rb
rotate(45)                                  # default color
rotate(45, background: :transparent)        # transparent
rotate(45, background: [65, 105, 225])      # RGB value
rotate(45, background: [65, 105, 225, 1.0]) # RGBA value
rotate(45, background: "...")               # any supported ImageMagick color value
```

#### `#composite`

Blends the image with the specified image and an optional mask. One use case
for this can be applying a [watermark].

```rb
composite(overlay)
composite(overlay, mask: mask)
```

The overlay and mask image can be a `String`, `Pathname`, or an object that
responds to `#path`.

The method of [image composition] can be specified via the `:mode` option (see
[Compose Tables] for a visual representation of the available methods), and
additional arguments for the compose method can be specified via `:args`:

```rb
composite(overlay, mode: "src")
composite(overlay, mode: "blend", args: "50,50")
```

The [direction] and [position] of the source or overlay image can be controlled
via `:gravity` and `:offset` options:

```rb
composite(overlay, gravity: "south-east")
composite(overlay, gravity: "north-west", offset: [55, 55])
```

Any additional options can be specified via a block:

```rb
composite(overlay) do |cmd|
  cmd.define("compose:outside-overlay=false")
  cmd.background("none")
  cmd.swap.+
end
```

See [`-composite`] for more details.

#### `#convert`

Specifies the output format.

```rb
pipeline = ImageProcessing::MiniMagick.source(image)

result = pipeline.convert!("png")

File.extname(result.path)
#=> ".png"
```

By default the original format is retained when writing the image to a file. If
the source file doesn't have a file extension, the format will default to JPEG.

#### `#define`

Adds coder/decoder options with [`-define`] from the specified Hash.

```rb
ImageProcessing::MiniMagick
  .define(png: { compression_level: 8, format: "png8" }) # -define png:compression-level=8 -define png:format=png8
  # ...
```

#### `#method_missing`

Any unknown methods will be delegated to [`MiniMagick::Tool::Convert`]. See the
list of all available options by running `convert -help` and visiting the
[ImageMagick reference].

```rb
ImageProcessing::MiniMagick
  .quality(100)        # -quality 100
  .crop("300x300+0+0") # -crop 300x300+0+0
  .resample("300x300") # -resample 300x300
  .stack { |cmd| ... } # ( ... )
  # ...
```

#### `#custom`

Yields the intermediary `MiniMagick::Tool::Convert` object. If the block return
value is a `MiniMagick::Tool::Convert` object it will be used in further
processing, otherwise if `nil` is returned the original
`MiniMagick::Tool::Convert` object will be used.

```rb
ImagePocessing::MiniMagick
  .custom { |magick| magick.colorspace("grayscale") if gray? }
  # ...
```

#### `#append`

Appends given values directly as arguments to the `convert` command.

```rb
ImageProcessing::MiniMagick
  .append("-quality", 100)
  .append("-flip")
  # ...
```

#### `#loader`

It accepts the following special options:

* `:loader` -- explicitly set the input file type
* `:page` -- specific page(s) that should be loaded
* `:geometry` -- geometry that should be applied when loading
* `:auto_orient` -- whether the image should be automatically oriented after it's loaded (defaults to `true`)
* `:define` -- creates definitions that coders and decoders use for reading and writing image data

```rb
ImageProcessing::MiniMagick.loader(loader: "jpg").call(image)
# convert jpg:input.jpg -auto-orient output.jpg

ImageProcessing::MiniMagick.loader(page: 0).convert("png").call(pdf)
# convert input.pdf[0] -auto-orient output.png

ImageProcessing::MiniMagick.loader(geometry: "300x300").call(image)
# convert input.jpg[300x300] -auto-orient output.jpg

ImageProcessing::MiniMagick.loader(auto_orient: false).call(image)
# convert input.jpg output.jpg

ImageProcessing::MiniMagick.loader(define: { jpeg: { size: "300x300" } }).call(image)
# convert -define jpeg:size=300x300 input.jpg -auto-orient output.jpg
```

All other options given will be interpreted as ImageMagick operations to be
applied before the image is loaded. Operation values can be either a single
argument, an array of arguments, `true`/`nil` indicating no arguments, or
`false` indicating the operator should be a "+" operator. See [Reading JPEG
Control Options] for some examples.

```rb
ImageProcessing::MiniMagick
  .loader(strip: true, type: "TrueColorMatte")
  .call(image) # convert -strip -type TrueColorMatte input.jpg ... output.jpg
```

If the `#loader` clause is repeated multiple times, the options are merged.

```rb
ImageProcessing::MiniMagick
  .loader(page: 0)
  .loader(geometry: "300x300")

# resolves to

ImageProcessing::MiniMagick
  .loader(page: 0, geometry: "300x300")
```

If you would like to have more control over loading, you can create the
`MiniMagick::Tool` object directly, and just pass it as the source file.

```rb
magick = MiniMagick::Tool::Convert.new
magick << "..." << "..." << "..."

ImageProcessing::MiniMagick
  .source(magick)
  # ...
```

#### `#saver`

It accepts the following special options:

* `:define` -- definitions that coders and decoders use for reading and writing image data
* `:allow_splitting` -- allow splitting multi-layer image into multiple single-layer images (defaults to `false`)

```rb
ImageProcessing::MiniMagick.saver(define: { jpeg: { optimize_coding: false } }).call(image)
# convert input.jpg -auto-orient -define jpeg:optimize-coding=false output.jpg

ImageProcessing::MiniMagick.convert("png").call(pdf_document)
# raises ImageProcessing::Error

ImageProcessing::MiniMagick.convert("png").saver(allow_splitting: true).call(pdf_document)
# lets ImageMagick generate a "*-{idx}.png" image for each page
```

All other options given will be interpreted as ImageMagick operations to be
applied before the image is saved. Operation values can be either a single
argument, an array of arguments, `true`/`nil` indicating no arguments, or
`false` indicating the operator should be a "+" operator. See [Writing JPEG
Control Options] for some examples. Note that is just syntax sugar over
applying the operations via the chainable API.

```rb
ImageProcessing::MiniMagick
  .saver(quality: 80, interlace: "Line")
  .call(image) # convert input.jpg ... -quality 80 -interlace Line output.jpg
```

If you would like to have more control over saving, you can call `#call(save:
false)` to get the `MiniMagick::Tool` object, and finish saving yourself.

```rb
magick = ImageProcessing::MiniMagick
  .resize_to_limit(400, 400)
  .call(save: false)

magick #=> #<MiniMagick::Tool::Convert ...>

magick << "output.png"
magick.call
```

#### `#limits`

Sets the pixel cache resource limits for the ImageMagick command.

```rb
ImageProcessing::MiniMagick
  .limits(memory: "50MiB", width: "10MP", time: 30)
  .resize_to_limit(400, 400)
  .call(image)

# convert -limit memory 50MiB -limit width 10MP -limit time 30 input.jpg ... output.jpg
```

See the [`-limit`] documentation and the [Architecture] article for more
details.

#### `#apply`

This is a convenience method for sending multiple commands to the builder using
a hash. Hash keys can be any method that the builder responds to. Hash values
can be either a single argument, an array of arguments, or `true`/`nil`
indicating no arguments. Instead of a hash you can also use an array if you
want to send multiple commands with the same name.

```rb
ImageProcessing::MiniMagick
  .apply(
    strip: true,
    crop: "200x200+0+0",
    resize_to_limit: [400, 400],
    convert: "jpg",
    saver: { quality: 100 },
  )
  # ...
```

## Sharpening

All `#resize_*` operations will automatically sharpen the resulting thumbnails
after resizing, using the [`-sharpen`] option.

```rb
ImageProcessing::MiniMagick
  .source(image)
  .resize_to_limit!(400, 400)

# convert input.jpg -resize 400x400> -sharpen 0x1 output.jpg
```

You can modify the radius and sigma of the Gaussian operator via the `:sharpen`
option (higher sigma means more sharpening):

```rb
ImageProcessing::MiniMagick
  .source(image)
  .resize_to_limit!(400, 400, sharpen: { radius: 1, sigma: 2 })
```

You can disable automatic sharpening by setting `:sharpen` to `false`:

```rb
ImageProcessing::MiniMagick
  .source(image)
  .resize_to_limit!(400, 400, sharpen: false)
```

[MiniMagick]: https://github.com/minimagick/minimagick
[ImageMagick]: https://www.imagemagick.org
[GraphicsMagick]: http://www.graphicsmagick.org
[installation instructions]: https://www.imagemagick.org/script/download.php
[fit]: http://www.imagemagick.org/Usage/thumbnails/#fit
[fill]: http://www.imagemagick.org/Usage/thumbnails/#cut
[pad]: http://www.imagemagick.org/Usage/thumbnails/#pad
[direction]: https://www.imagemagick.org/script/command-line-options.php#gravity
[color]: https://www.imagemagick.org/script/color.php
[ImageMagick reference]: https://www.imagemagick.org/script/command-line-options.php
[`MiniMagick::Tool::Convert`]: https://github.com/minimagick/minimagick#metal
[Reading JPEG Control Options]: http://www.imagemagick.org/Usage/formats/#jpg_read
[Writing JPEG Control Options]: http://www.imagemagick.org/Usage/formats/#jpg_write
[`-limit`]: https://www.imagemagick.org/script/command-line-options.php#limit
[Architecture]: https://www.imagemagick.org/script/architecture.php#cache
[`-sharpen`]: https://www.imagemagick.org/script/command-line-options.php#sharpen
[`-define`]: https://www.imagemagick.org/script/command-line-options.php#define
[`-rotate`]: https://www.imagemagick.org/script/command-line-options.php#rotate
[watermark]: https://en.wikipedia.org/wiki/Watermark
[image composition]: https://www.imagemagick.org/script/compose.php
[Compose Tables]: http://www.imagemagick.org/Usage/compose/tables/
[position]: https://www.imagemagick.org/script/command-line-processing.php#geometry
[`-composite`]: https://www.imagemagick.org/script/command-line-options.php#composite
