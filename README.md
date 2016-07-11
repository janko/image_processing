# ImageProcessing

Provides higher-level helper methods for image processing in Ruby using
ImageMagick.

These methods were extracted from [refile-mini_magick], and were made generic so
that they can be used in any project. The goal of image_processing is to have a
centralized place where helper methods for image processing are maintained,
instead of CarrierWave, Dragonfly and Refile each implementing their own.

It's been tested with MRI 2.x, JRuby and Rubinius.

## Installation

```ruby
gem 'image_processing'
gem 'mini_magick', '>= 4.3.5'
```

## Usage

Typically you will include the module in your class:

```rb
require "image_processing/mini_magick"

include ImageProcessing::MiniMagick

original = File.open("path/to/image.jpg")

converted = convert(original, "png") # makes a converted copy
converted #=> #<Tempfile:/var/folders/k7/6zx6dx6x7ys3rv3srh0nyfj00000gn/T/mini_magick20151003-23030-9e1vjz.png (closed)>
File.exist?(original.path) #=> true

converted = convert!(original, "png") # destructively converts the file
converted #=> #<Tempfile:/var/folders/k7/6zx6dx6x7ys3rv3srh0nyfj00000gn/T/mini_magick20151003-23030-9e1vjz.png (closed)>
File.exist?(original.path) #=> false
```

If you would rather not pollute your namespace, you can also call the methods
directly on the module:

```rb
image = File.open("path/to/image.jpg")

ImageProcessing::MiniMagick.resize_to_fit(image, 400, 400)
```

The following is the list of helper methods that ImageProcessing provides (each
one has both a destructive and a nondestructive version):

```rb
# Adjust an image so that its orientation is suitable for viewing.
auto_orient[!](file)

# Converts file to the specified format.
convert[!](file, format)

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

If you want to do custom MiniMagick processing, each of the above optionally
yields an instance of `MiniMagick::Tool`, so you can use it for additional
processing:

```rb
convert(file, "png") do |cmd|
  cmd.background("none")
end
```

There is also a helper method for doing MiniMagick processing directly:

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

ImageMagick and GraphicsMagick are both required to be installed, on Mac this is

```
$ brew install imagemagick
$ brew install graphicsmagick
```

Run tests with

```
$ rake test
```

## License

[MIT](LICENSE.txt)

[refile-mini_magick]: https://github.com/refile/refile-mini_magick
