# ImageProcesing::Vips

The `ImageProcessing::Vips` module contains processing macros that use the
[ruby-vips] gem, which you need to install:

```rb
# Gemfile
gem "ruby-vips", "~> 2.0"
```

Note that you'll need to have [libvips] 8.6 or higher installed; see the
[installation instructions] for more details.

## Methods

#### `.valid_image?`

Returns true if the image is processable, and false if it's corrupted or not
supported by libvips.

```rb
ImageProcessing::Vips.valid_image?(normal_image)    #=> true
ImageProcessing::Vips.valid_image?(corrupted_image) #=> false
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
original aspect ratio. If necessary, will pad the remaining area with the given
color.

```rb
pipeline = ImageProcessing::Vips.source(image) # 600x800

result = pipeline.resize_and_pad!(400, 400)

Vips::Image.new_from_file(result.path).size #=> [400, 400]
```

It accepts `:background` for specifying the background [color] that will be
used for padding (defaults to black).

```rb
pipeline.resize_and_pad!(400, 400, color: "RoyalBlue")
# or
pipeline.resize_and_pad!(400, 400, color: [65, 105, 225])
```

It also accepts `:gravity` for specifying the [direction] where the source
image will be positioned (defaults to `"centre"`).

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

Calls the provided block with the intermediary `Vips::Image` object. The return
value of the provided block must be a `Vips::Image` object.

```rb
ImageProcessing::Vips
  .custom { |image| image + image.invert }
  # ...
```

### `#loader`

Specifies options that will be forwarded to [`Vips::Image.new_from_file`].

```rb
ImageProcessing::Vips
  .loader(access: :sequential)
  # ...
```

See [`vips_jpegload()`], [`vips_pngload()`] etc. for more details on
format-specific load options. Note that `:fail` is set to `true` by default, so
that an exception is raised when the image is corrupted.

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
  .saver(Q: 100, interlace: true)
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

[ruby-vips]: https://github.com/jcupitt/ruby-vips
[libvips]: https://github.com/jcupitt/libvips
[installation instructions]: https://github.com/jcupitt/libvips/wiki#building-and-installing
[`Vips::Image`]: http://www.rubydoc.info/gems/ruby-vips/Vips/Image
[`Vips::Image.new_from_file`]: http://www.rubydoc.info/gems/ruby-vips/Vips/Image#new_from_file-class_method
[`Vips::Image#write_to_file`]: http://www.rubydoc.info/gems/ruby-vips/Vips/Image#write_to_file-instance_method
[`Vips::Image#thumbnail_image`]: http://www.rubydoc.info/gems/ruby-vips/Vips/Image#thumbnail_image-instance_method
[`Vips::Image#set`]: http://www.rubydoc.info/gems/ruby-vips/Vips/Image#set-instance_method
[`Vips::Image#set_type`]: http://www.rubydoc.info/gems/ruby-vips/Vips/Image#set_type-instance_method
[`vips_thumbnail()`]: https://jcupitt.github.io/libvips/API/current/libvips-resample.html#vips-thumbnail
[`vips_gravity()`]: http://jcupitt.github.io/libvips/API/current/libvips-conversion.html#vips-gravity
[`vips_autorot()`]: https://jcupitt.github.io/libvips/API/current/libvips-conversion.html#vips-autorot
[`vips_jpegload()`]: https://jcupitt.github.io/libvips/API/current/VipsForeignSave.html#vips-jpegload
[`vips_pngload()`]: https://jcupitt.github.io/libvips/API/current/VipsForeignSave.html#vips-pngload
[`vips_jpegsave()`]: https://jcupitt.github.io/libvips/API/current/VipsForeignSave.html#vips-jpegsave
[`vips_pngsave()`]: https://jcupitt.github.io/libvips/API/current/VipsForeignSave.html#vips-pngsave
[color]: https://www.imagemagick.org/script/color.php#color_names
[direction]: http://jcupitt.github.io/libvips/API/current/libvips-conversion.html#VipsCompassDirection
