# ImageProcessing::MiniMagick

The `ImageProcessing::MiniMagick` module contains processing methods that use
the [MiniMagick] gem (which is installed when you install image_processing).

## Installation

You will need to install ImageMagick before using this module:

`$ brew install imagemagick`

If you would prefer to not use Homebrew when installing [ImageMagick], 
see the [installation instructions] for other options.

This processor does some useful things by default:

* images are automatically oriented on load to make them upright (using [`-auto-orient`])
* `#resize_*` operations will automatically sharpen the resized images (using [`-sharpen`])

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

It accepts `:gravity` for specifying the [gravity] to apply while cropping
(defaults to `"Center"`).

```rb
pipeline.resize_to_fill!(400, 400, gravity: "NorthWest")
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
pipeline.resize_and_pad!(400, 400, background: "RoyalBlue")
pipeline.resize_and_pad!(400, 400, background: :transparent) # default
```

It accepts `:gravity` for specifying the [gravity] to apply while cropping
(defaults to `"Center"`).

```rb
pipeline.resize_and_pad!(400, 400, gravity: "NorthWest")
```

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

#### `#method_missing`

Any unknown methods will be delegated to [`MiniMagick::Tool::Convert`].

```rb
ImageProcessing::MiniMagick
  .quality(100)
  .crop("300x300+0+0")
  .resample("300x300")
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

* `:page` -- specific page(s) that should be loaded
* `:geometry` -- geometry that should be applied when loading
* `:auto_orient` -- whether the image should be automatically oriented after it's loaded (defaults to `true`)
* `:define` -- creates definitions that coders and decoders use for reading and writing image data

```rb
ImageProcessing::MiniMagick.loader(page: 0).convert("png").call(pdf)
# convert input.pdf[0] -regard-warnings -auto-orient output.png

ImageProcessing::MiniMagick.loader(geometry: "300x300").call(image)
# convert input.jpg[300x300] -regard-warnings -auto-orient output.jpg

ImageProcessing::MiniMagick.loader(auto_orient: false).call(image)
# convert input.jpg -regard-warnings output.jpg

ImageProcessing::MiniMagick.loader(define: { jpeg: { size: "300x300" } }).call(image)
# convert -define jpeg:size=300x300 input.jpg -regard-warnings -auto-orient output.jpg
```

All other options given will be interpreted as direct options to be applied
before the image is loaded (see [Reading JPEG Control Options] for some
examples).

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

```rb
ImageProcessing::MiniMagick.saver(define: { jpeg: { optimize_coding: false } }).call(image)
# convert input.jpg -regard-warnings -auto-orient -define jpeg:optimize-coding=false output.jpg
```

All other options given will be interpreted as direct options to be applied
before the image is saved (see [Writing JPEG Control Options] for some
examples). This is the same as applying the options via the chainable API.

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

See the [`-limit`] documentation and the [Architecture] article.

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
[installation instructions]: https://www.imagemagick.org/script/download.php
[fit]: http://www.imagemagick.org/Usage/thumbnails/#fit
[fill]: http://www.imagemagick.org/Usage/thumbnails/#cut
[pad]: http://www.imagemagick.org/Usage/thumbnails/#pad
[gravity]: https://www.imagemagick.org/script/command-line-options.php#gravity
[color]: https://www.imagemagick.org/script/color.php
[`MiniMagick::Tool::Convert`]: https://github.com/minimagick/minimagick#metal
[Reading JPEG Control Options]: http://www.imagemagick.org/Usage/formats/#jpg_read
[Writing JPEG Control Options]: http://www.imagemagick.org/Usage/formats/#jpg_write
[`-limit`]: https://www.imagemagick.org/script/command-line-options.php#limit
[Architecture]: https://www.imagemagick.org/script/architecture.php#cache
[`-sharpen`]: https://www.imagemagick.org/script/command-line-options.php#sharpen
[`-auto-orient`]: https://www.imagemagick.org/script/command-line-options.php#auto-orient
[`-regard-warnings`]: https://www.imagemagick.org/script/command-line-options.php#regard-warnings
