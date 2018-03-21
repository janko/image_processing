# ImageProcessing::MiniMagick

The `ImageProcessing::MiniMagick` module contains processing methods that use
the [MiniMagick] gem, which you need to install:

```rb
# Gemfile
gem "mini_magick", "~> 4.0"
```

You'll need to have [ImageMagick] or [GraphicsMagick] installed, see the
[installation instructions] for more details.

## Methods

#### `.valid_image?`

Returns true if the image is processable, and false if it's corrupted or not
supported by imagemagick.

```rb
ImageProcessing::MiniMagick.valid_image?(normal_image)    #=> true
ImageProcessing::MiniMagick.valid_image?(corrupted_image) #=> false
```

#### `#resize_to_limit`

Downsizes the image to fit within the specified dimensions while retaining the
original aspect ratio. Will only resize the image if it's larger than the
specified dimensions.

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
*original aspect ratio. Will downsize the image if it's larger than the
specified dimensions or upsize if it's smaller.

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
aspect ratio. If necessary, will crop the image in the larger dimension.

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
color.

```rb
pipeline = ImageProcessing::MiniMagick.source(image) # 600x800

result = pipeline.resize_and_pad!(400, 400)

MiniMagick::Image.new(result.path).dimensions #=> [400, 400]
```

It accepts `:background` for specifying the background [color] that will be
used for padding (defaults to transparent/white).

```rb
pipeline.resize_and_pad!(400, 400, color: "RoyalBlue")
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

Any unknown methods will be appended directly as `convert`/`magick` options.

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

It accepts the following options:

* `:page` -- specific page(s) that should be loaded
* `:geometry` -- geometry that should be applied when loading
* `:fail` -- whether processing should fail on warnings (defaults to `true`)
* `:auto_orient` -- whether the image should be automatically oriented after it's loaded (defaults to `true`)

```rb
ImageProcessing::MiniMagick.source(document).loader(page: 0).convert!("png")
# convert input.pdf[0] output.png

ImageProcessing::MiniMagick.source(image).loader(geometry: "300x300").convert!("png")
# convert input.jpg[300x300] output.png

ImageProcessing::MiniMagick.source(image).loader(fail: false).convert!("png")
# convert -regard-warnings input.jpg output.png (raises MiniMagick::Error in case of warnings)
```

[MiniMagick]: https://github.com/minimagick/minimagick
[ImageMagick]: https://www.imagemagick.org
[GraphicsMagick]: http://www.graphicsmagick.org
[installation instructions]: https://www.imagemagick.org/script/download.php
[gravity]: https://www.imagemagick.org/script/command-line-options.php#gravity
[color]: https://www.imagemagick.org/script/color.php#color_names
