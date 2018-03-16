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

## ruby-vips

The `ImageProcessing::Vips` module contains processing macros that use the
[ruby-vips] gem, which you need to install:

```rb
# Gemfile
gem "ruby-vips", "~> 2.0"
```

Note that you'll need to have [libvips] 8.6 or higher installed; see
the [installation instructions][libvips installation] for more details.

### Usage

`ImageProcessing::Vips` lets you define the processing pipeline using a
chainable API:

```rb
require "image_processing/vips"

processed = ImageProcessing::Vips
  .convert("png")
  .resize_to_limit(400, 400)
  .call(image)

processed #=> #<File:/var/folders/.../image_processing-vips20180316-18446-1j247h6.png>
```

The processing is executed on `#call` or when a processing method is called
with a bang (`!`).

```rb
processed = ImageProcessing::Vips
  .convert("png")
  .resize_to_limit(400, 400)
  .call(image)

# OR

processed = ImageProcessing::Vips
  .source(image) # declare source image
  .convert("png")
  .resize_to_limit(400, 400)
  .call

# OR

processed = ImageProcessing::Vips
  .source(image)
  .convert("png")
  .resize_to_limit!(400, 400) # bang method
```

The source image needs to be an object that responds to `#path` or a
`Vips::Image` object. The result is a `Tempfile` object, or a `Vips::Image`
object if `save: false` is passed in.

```rb
pipeline = ImageProcessing::Vips.source(image)

tempfile = pipeline.call
tempfile #=> #<Tempfile ...>

vips_image = pipeline.call(save: false)
vips_image #=> #<Vips::Image ...>
```

#### `#resize_to_limit`

Downsizes the image to fit within the specified dimensions while retaining the
original aspect ratio. Will only resize the image if it's larger than the
specified dimensions.

```rb
pipeline = ImageProcessing::Vips.source(image) # 600x800

result = pipeline.resize_to_limit!(400, 400)

Vips::Image.new_from_file(result.path).size
#=> [300, 400]
```

It's possible to omit one dimension, in which case the image will be resized
only by the provided dimension.

```rb
pipeline.resize_to_limit!(400, nil)
# or
pipeline.resize_to_limit!(nil, 400)
```

Any additional options are forwarded to [`Vips::Image#thumbnail_image`]:

```rb
pipeline.resize_to_limit!(400, 400, linear: true)
```

See [`vips_thumbnail()`] for more details.

#### `#resize_to_fit`

Resizes the image to fit within the specified dimensions while retaining the
original aspect ratio. Will downsize the image if it's larger than the
specified dimensions or upsize if it's smaller.

```rb
pipeline = ImageProcessing::Vips.source(image) # 600x800

result = pipeline.resize_to_fit!(400, 400)

Vips::Image.new_from_file(result.path).size
#=> [300, 400]
```

It's possible to omit one dimension, in which case the image will be resized
only by the provided dimension.

```rb
pipeline.resize_to_fit!(400, nil)
# or
pipeline.resize_to_fit!(nil, 400)
```

Any additional options are forwarded to [`Vips::Image#thumbnail_image`]:

```rb
pipeline.resize_to_fit!(400, 400, linear: true)
```

See [`vips_thumbnail()`] for more details.

#### `#resize_to_fill`

Resizes the image to fill the specified dimensions while retaining the original
aspect ratio. If necessary, will crop the image in the larger dimension.

```rb
pipeline = ImageProcessing::Vips.source(image) # 600x800

result = pipeline.resize_to_fill!(400, 400)

Vips::Image.new_from_file(result.path).size
#=> [400, 400]
```

Any additional options are forwarded to [`Vips::Image#thumbnail_image`]:

```rb
pipeline.resize_to_fill!(400, 400, crop: :attention) # smart crop
```

See [`vips_thumbnail()`] for more details.

#### `#resize_and_pad`

Resizes the image to fit within the specified dimensions while retaining the
original aspect ratio. If necessary, will pad the remaining area with the given
color, which defaults to transparent (for GIF and PNG, white for JPEG).

```rb
pipeline = ImageProcessing::Vips.source(image) # 600x800

result = pipeline.resize_and_pad!(400, 400)

Vips::Image.new_from_file(result.path).size
#=> [400, 400]
```

You can specify the background [color] that will be used for padding:

```rb
pipeline.resize_and_pad!(400, 400, color: "RoyalBlue")
```

You can also specify the [direction] where the source image will be positioned:

```rb
pipeline.resize_and_pad!(400, 400, gravity: "north-west")
```

Any additional options are forwarded to [`Vips::Image#thumbnail_image`]:

```rb
pipeline.resize_to_fill!(400, 400, linear: true)
```

See [`vips_thumbnail()`] and [`vips_gravity()`] for more details.

#### `#convert`

Specifies the output format.

```rb
pipeline = ImageProcessing::Vips.source(image)

result = pipeline.convert!("png")

File.extname(result.path)
#=> ".png"
```

By default the original format is retained when writing the image to a file. If
the source file doesn't have a file extension, the format will default to JPEG.

#### `#set`, `#set_type`

Sets `Vips::Image` metadata. Delegates to [`Vips::Image#set`] and
[`Vips::Image#set_type`].

```rb
pipeline = ImageProcessing::Vips.source(image)

pipeline.set("icc-profile-data", profile).call
# or
pipeline.set_type(Vips::BLOB_TYPE, "icc-profile-data", profile).call
```

#### `#method_missing`

Any unknown methods will be delegated to [`Vips::Image`].

```rb
ImageProcessing::Vips
  .crop(0, 0, 300, 300)
  .invert
  .gaussblur(2)
  # ...
```

#### `#custom`

Calls the provided block with the intermediary `Vips::Image` object. The return
value of the provided block must be a `Vips::Image` object.

```rb
ImageProcessing::Vips
  .source(file)
  .resize_to_limit(400, 400)
  .custom { |image| image + image.invert }
  .call
```

#### `#loader`

Specifies options that will be forwarded to [`Vips::Image.new_from_file`].

```rb
ImageProcessing::Vips
  .loader(access: :sequential)
  .resize_to_limit(400, 400)
  .call(source)
```

See [`vips_jpegload()`], [`vips_pngload()`] etc. for more details on
format-specific load options.

If you would like to have more control over loading, you can load the image
directly using `Vips::Image`, and just pass the `Vips::Image` object as the
source file.

```rb
vips_image = Vips::Image.magickload(file.path, n: -1)

ImageProcessing::Vips
  .source(vips_image)
  # ...
```

#### `#saver`

Specifies options that will be forwarded to [`Vips::Image#write_to_file`].

```rb
ImageProcessing::Vips
  .saver(Q: 100)
  .resize_to_limit(400, 400)
  .call(source)
```

See [`vips_jpegsave()`], [`vips_pngsave()`] etc. for more details on
format-specific save options.

If you would like to have more control over saving, you can call `#call(save:
false)` to get the `Vips::Image` object, and call the saver on it directly.

```rb
vips_image = ImageProcessing::Vips
  .resize_to_limit(400, 400)
  .call(save: false)

vips_image.write_to_file("/path/to/destination", **options)
```

## MiniMagick

The `ImageProcessing::MiniMagick` module contains processing methods that use
the [MiniMagick] gem, which you need to install:

```rb
# Gemfile
gem "mini_magick", ">= 4.3.5"
```

Typically you will include the module in your class:

```rb
require "image_processing/mini_magick"

include ImageProcessing::MiniMagick

original = File.open("path/to/image.jpg")

converted = convert(original, "png") # makes a converted copy
converted #=> #<File:/var/folders/.../mini_magick20151003-23030-9e1vjz.png (closed)>
File.exist?(original.path) #=> true

converted = convert!(original, "png") # converts the file in-place
converted #=> #<File:/var/folders/.../mini_magick20151003-23030-9e1vjz.png (closed)>
File.exist?(original.path) #=> false
```

You can also call processing methods directly on the module:

```rb
image = File.open("path/to/image.jpg")

ImageProcessing::MiniMagick.resize_to_fit(image, 400, 400)
```

### Methods

The following is the list of processing methods provided by
`ImageProcessing::MiniMagick` (each one has both a destructive and a
nondestructive version):

```rb
# Adjust an image so that its orientation is suitable for viewing.
auto_orient[!](file)

# Converts file to the specified format, and you can specify to convert only a
# certain page for multilayered formats.
convert[!](file, format, page = nil)

# Crop image to the defined area.
crop[!](file, width, height, x_offset, y_offset, gravity: "NorthWest")

# Resizes image to fit the specified dimensions (shrinks if larger, enlarges if
# smaller, but keeps the aspect ratio).
resize_to_fit[!](file, width, height)

# Resizes image in limit of the specified dimensions (shrinks if larger, keeps
# if smaller, but keeps the aspect ratio).
resize_to_limit[!](file, width, height)

# Resizes image to fill the specified dimensions (shrinks if larger,
# enlarges if smaller, crops the longer side).
resize_to_fill[!](file, width, height, gravity: "Center")

# Resizes image to the specified dimensions and pads missing space (shrinks if
# larger, enlarges if smaller, fills the shorter side with specified color).
resize_and_pad[!](file, width, height, background: "transparent", gravity: "Center")

# Resamples the image to a different resolution
resample[!](file, horizontal, vertical)

# Returns true if the given image is corrupted
currupted?(file)
```

The `#resize_to_limit[!]` and `#resize_to_fit[!]` allow specifying only one
dimension:

```rb
resize_to_limit(image, 300, nil)
resize_to_fit(image, nil, 500)
```

### Dropping to MiniMagick

If you want to do custom MiniMagick processing, each of the above optionally
yields an instance of `MiniMagick::Tool`, which you can use for additional
processing:

```rb
convert(file, "png") do |cmd|
  cmd.background("none")
end
```

There is also a helper method for doing MiniMagick processing directly (though
note that this will process the image in-place!):

```rb
processed = with_minimagick(file) do |image|
  image #=> #<MiniMagick::Image ...>
  image.combine_options do |cmd|
    # ...
  end
end

processed #=> #<File ...>
```

## Contributing

Test suite requires `imagemagick`, `graphicsmagick` and `libvips` be installed.
On Mac OS you can install them with Homebrew:

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
[MiniMagick]: https://github.com/minimagick/minimagick
[ruby-vips]: https://github.com/jcupitt/ruby-vips
[libvips]: https://github.com/jcupitt/libvips
[libvips installation]: https://github.com/jcupitt/libvips/wiki#building-and-installing
[refile-mini_magick]: https://github.com/refile/refile-mini_magick
[`Vips::Image`]: http://www.rubydoc.info/gems/ruby-vips/Vips/Image
[`Vips::Image.new_from_file`]: http://www.rubydoc.info/gems/ruby-vips/Vips/Image#new_from_file-class_method
[`Vips::Image#write_to_file`]: http://www.rubydoc.info/gems/ruby-vips/Vips/Image#write_to_file-instance_method
[`Vips::Image#thumbnail_image`]: http://www.rubydoc.info/gems/ruby-vips/Vips/Image#thumbnail_image-instance_method
[`Vips::Image#set`]: http://www.rubydoc.info/gems/ruby-vips/Vips/Image#set-instance_method
[`Vips::Image#set_type`]: http://www.rubydoc.info/gems/ruby-vips/Vips/Image#set_type-instance_method
[`vips_thumbnail()`]: https://jcupitt.github.io/libvips/API/current/libvips-resample.html#vips-thumbnail
[`vips_gravity()`]: http://jcupitt.github.io/libvips/API/current/libvips-conversion.html#vips-gravity
[`vips_jpegload()`]: https://jcupitt.github.io/libvips/API/current/VipsForeignSave.html#vips-jpegload
[`vips_pngload()`]: https://jcupitt.github.io/libvips/API/current/VipsForeignSave.html#vips-pngload
[`vips_jpegsave()`]: https://jcupitt.github.io/libvips/API/current/VipsForeignSave.html#vips-jpegsave
[`vips_pngsave()`]: https://jcupitt.github.io/libvips/API/current/VipsForeignSave.html#vips-pngsave
[color]: https://www.imagemagick.org/script/color.php#color_names
[direction]: http://jcupitt.github.io/libvips/API/current/libvips-conversion.html#VipsCompassDirection
