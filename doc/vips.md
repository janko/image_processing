# ImageProcessing::Vips

The `ImageProcessing::Vips` module contains processing macros that use the
[ruby-vips] gem (which is installed with the image_processing gem).

## Installation

You will need to install [libvips] before using this module:

```sh
$ brew install vips
```

If you're using something other than Homebrew, see the [installation
instructions] for more details.

NOTE: libvips 8.6 or higher is required.

## Usage

```rb
require "image_processing/vips"

processed = ImageProcessing::Vips
  .source(image)
  .resize_to_limit(400, 400)
  .saver(strip: true)
  .call

processed #=> #<Tempfile:/var/folders/.../image_processing20180316-18446-1j247h6.png>
```

## Methods

#### `.valid_image?`

Tries to calculate the image average using sequential access, and returns
`true` if no exception was raised, otherwise returns `false`.

```rb
ImageProcessing::Vips.valid_image?(normal_image)  #=> true
ImageProcessing::Vips.valid_image?(invalid_image) #=> false
```

#### `#resize_to_limit`

Downsizes the image to fit within the specified dimensions while retaining the
original aspect ratio. Will only resize the image if it's larger than the
specified dimensions.

```rb
pipeline = ImageProcessing::Vips.source(image) # 600x800

result = pipeline.resize_to_limit!(400, 400)

Vips::Image.new_from_file(result.path).size #=> [300, 400]
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

Vips::Image.new_from_file(result.path).size #=> [300, 400]
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

Vips::Image.new_from_file(result.path).size #=> [400, 400]
```

Any additional options are forwarded to [`Vips::Image#thumbnail_image`]:

```rb
pipeline.resize_to_fill!(400, 400, crop: :attention) # smart crop
```

See [`vips_thumbnail()`] for more details.

#### `#resize_and_pad`

Resizes the image to fit within the specified dimensions while retaining the
original aspect ratio. If necessary, will pad the remaining area with
transparent color if source image has alpha channel, black otherwise.

```rb
pipeline = ImageProcessing::Vips.source(image) # 600x800

result = pipeline.resize_and_pad!(400, 400)

Vips::Image.new_from_file(result.path).size #=> [400, 400]
```

If you're converting from a format that doesn't support transparent colors
(e.g. JPEG) to a format that does (e.g. PNG), setting `:alpha` to `true` will
add the alpha channel to the image:

```rb
pipeline.resize_and_pad!(400, 400, alpha: true)
```

The `:extend` and `:background` options are also accepted and are forwarded to
[`Vips::Image#gravity`]:

```rb
pipeline.resize_and_pad!(400, 400, extend: :copy)
```

The `:gravity` option can be used to specify the [direction] where the source
image will be positioned (defaults to `"centre"`).

```rb
pipeline.resize_and_pad!(400, 400, gravity: "north-west")
```

Any additional options are forwarded to [`Vips::Image#thumbnail_image`]:

```rb
pipeline.resize_to_fill!(400, 400, linear: true)
```

See [`vips_thumbnail()`] and [`vips_gravity()`] for more details.

#### `#rotate`

Rotates the image by the specified angle.

```rb
ImageProcessing::Vips
  .rotate(90)
  # ...
```

For degrees that are not a multiple of 90, you can also specify a background
color for the empty triangles in the corners, left over from rotating the image.

```rb
ImageProcessing::Vips
  .rotate(45, background: [0, 0, 0])
  # ...
```

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

NOTE: GIF support in `ImageProcessing::Vips` is limited. You can read GIF files
(and convert them to other formats), but you can't save GIF files. If you need
full GIF support, we recommend using `ImageProcessing::MiniMagick` instead.

#### `#method_missing`

Any unknown methods will be delegated to [`Vips::Image`].

```rb
ImageProcessing::Vips
  .crop(0, 0, 300, 300)
  .invert
  .set("icc-profile-data", custom_profile)
  .gaussblur(2)
  # ...
```

#### `#custom`

Yields the intermediary `Vips::Image` object. If the block return value is a
`Vips::Image` object it will be used in further processing, otherwise if `nil`
is returned the original `Vips::Image` object will be used.

```rb
ImageProcessing::Vips
  .custom { |image| image + image.invert if invert? }
  # ...
```

#### `#loader`

Specifies options that will be forwarded to [`Vips::Image.new_from_file`].

```rb
ImageProcessing::Vips
  .loader(access: :sequential)
  # ...
```

If the `#loader` clause is specified multiple times, the options are merged.

```rb
ImageProcessing::Vips
  .loader(page: 0)
  .loader(dpi: 300)

# resolves to

ImageProcessing::Vips
  .loader(page: 0, dpi: 300)
```

See [`vips_jpegload()`], [`vips_pngload()`] etc. for more details on
format-specific load options. Any provided options that are not defined for a
specific loader will be ignored.

An additional `:autorot` option is accepted to specify whether
[`vips_autorot()`] should be automatically called after the image is loaded
(defaults to `true`).

```rb
ImageProcessing::Vips
  .loader(autorot: false) # disable automatic rotation
  # ...
```

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
  .saver(quality: 100) # alias for :Q
  # ...
```

If the `#saver` clause is repeated multiple times, the options are merged.

```rb
ImageProcessing::Vips
  .saver(tile: true)
  .saver(compression: :lzw)

# resolves to

ImageProcessing::Vips
  .saver(tile: true, compression: :lzw)
```

See [`vips_jpegsave()`], [`vips_pngsave()`] etc. for more details on
format-specific save options. Any provided options that are not defined for a
specific saver will be ignored.

If you would like to have more control over saving, you can call `#call(save:
false)` to get the `Vips::Image` object, and call the saver on it directly.

```rb
vips_image = ImageProcessing::Vips
  .resize_to_limit(400, 400)
  .call(save: false)

vips_image #=> #<Vips::Image ...>

vips_image.write_to_file("/path/to/destination", **options)
```

#### `#apply`

This is a convenience method for sending multiple commands to the builder using
a hash. Hash keys can be any method that the builder responds to. Hash values
can be either a single argument, an array of arguments, or `true`/`nil`
indicating no arguments. Instead of a hash you can also use an array if you
want to send multiple commands with the same name.

```rb
ImageProcessing::Vips
  .apply(
    invert: true,
    smartcrop: [200, 200],
    resize_to_limit: [400, 400],
    convert: "jpg",
    saver: { quality: 100 },
  )
  # ...
```

## Sharpening

All `#resize_*` operations will automatically sharpen the resulting thumbnails
after resizing, using the following [convolution mask]:

```rb
Vips::Image.new_from_array [
  [-1, -1, -1],
  [-1, 32, -1],
  [-1, -1, -1]], 24
```

You can assign a different convolution mask via the `:sharpen` option:

```rb
sharpen_mask = Vips::Image.new_from_array [
  [-1, -1, -1],
  [-1, 24, -1],
  [-1, -1, -1]], 16

ImageProcessing::Vips
  .source(image)
  .resize_to_limit!(400, 400, sharpen: sharpen_mask)
```

You can disable automatic sharpening by setting `:sharpen` to `false`:

```rb
ImageProcessing::Vips
  .source(image)
  .resize_to_limit!(400, 400, sharpen: false)
```

[ruby-vips]: https://github.com/jcupitt/ruby-vips
[libvips]: https://github.com/jcupitt/libvips
[installation instructions]: https://github.com/jcupitt/libvips/wiki#building-and-installing
[`Vips::Image`]: http://www.rubydoc.info/gems/ruby-vips/Vips/Image
[`Vips::Image.new_from_file`]: http://www.rubydoc.info/gems/ruby-vips/Vips/Image#new_from_file-class_method
[`Vips::Image#write_to_file`]: http://www.rubydoc.info/gems/ruby-vips/Vips/Image#write_to_file-instance_method
[`Vips::Image#thumbnail_image`]: http://www.rubydoc.info/gems/ruby-vips/Vips/Image#thumbnail_image-instance_method
[`Vips::Image#gravity`]: http://www.rubydoc.info/gems/ruby-vips/Vips/Image#gravity-instance_method
[`vips_thumbnail()`]: https://jcupitt.github.io/libvips/API/current/libvips-resample.html#vips-thumbnail
[`vips_gravity()`]: http://jcupitt.github.io/libvips/API/current/libvips-conversion.html#vips-gravity
[`vips_autorot()`]: https://jcupitt.github.io/libvips/API/current/libvips-conversion.html#vips-autorot
[`vips_jpegload()`]: https://jcupitt.github.io/libvips/API/current/VipsForeignSave.html#vips-jpegload
[`vips_pngload()`]: https://jcupitt.github.io/libvips/API/current/VipsForeignSave.html#vips-pngload
[`vips_jpegsave()`]: https://jcupitt.github.io/libvips/API/current/VipsForeignSave.html#vips-jpegsave
[`vips_pngsave()`]: https://jcupitt.github.io/libvips/API/current/VipsForeignSave.html#vips-pngsave
[direction]: http://jcupitt.github.io/libvips/API/current/libvips-conversion.html#VipsCompassDirection
[convolution mask]: https://en.wikipedia.org/wiki/Kernel_(image_processing)
