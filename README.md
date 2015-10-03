# ImageProcessing

Provides higher-level helper methods for image processing in Ruby using
ImageMagick.

This methods were extracted from Refile, and were made generic so that they can
be used in any project. The goal is to have a centralized place where image
processing helper methods are maintained, instead of CarrierWave, Dragonfly and
Refile each having their own.

## Installation

```ruby
gem 'image_processing'
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

The following is the list of helper methods that ImageProcessing provides:

```rb
# Converts file to the specified format.
convert(file, format)  # nondestructive
convert!(file, format) # destructive

# Resizes image to fit the specified dimensions (shrinks if larger, enlarges if
# smaller, but keeps the aspect ratio).
resize_to_fit(file, width, height)  # nondestructive
resize_to_fit!(file, width, height) # destructive

# Resizes image in limit of the specified dimensions (shrinks if larger, keeps
# if smaller, but keeps the aspect ratio).
resize_to_limit(file, width, height)  # nondestructive
resize_to_limit!(file, width, height) # destructive

# Resizes image to fill the specified dimensions (shrinks if larger,
# enlarges if smaller, crops the longer side).
resize_to_fill(file, width, height, gravity: "Center")  # nondestructive
resize_to_fill!(file, width, height, gravity: "Center") # destructive

# Resizes image to the specified dimensions and pads missing space (shrinks if
# larger, enlarges if smaller, fills the shorter side with specified color).
resize_and_pad(file, width, height, background: "transparent", gravity: "Center")  # nondestructive
resize_and_pad!(file, width, height, background: "transparent", gravity: "Center") # destructive
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
