require "image_processing/version"
require "mini_magick"
require "tempfile"

if MiniMagick.version < Gem::Version.new("4.3.5")
  raise "image_processing requires mini_magick version >= 4.3.5"
end

module ImageProcessing
  module MiniMagick
    def self.nondestructive_alias(name, original)
      define_method(name) do |image, *args, &block|
        send(original, _copy_to_tempfile(image), *args, &block)
      end
    end

    module_function

    # Changes the image encoding format to the given format
    #
    # @see http://www.imagemagick.org/script/command-line-options.php#format
    # @param [MiniMagick::Image] image    the image to convert
    # @param [String] format              the format to convert to
    # @yield [MiniMagick::Tool::Mogrify, MiniMagick::Tool::Convert]
    # @return [File, Tempfile]
    def convert!(image, format, &block)
      _with_minimagick(image) do |img|
        img.format(format.downcase, nil, &block)
      end
    end
    nondestructive_alias :convert, :convert!

    # Resize the image to fit within the specified dimensions while retaining
    # the original aspect ratio. Will only resize the image if it is larger
    # than the specified dimensions. The resulting image may be shorter or
    # narrower than specified in either dimension but will not be larger than
    # the specified values.
    #
    # @param [MiniMagick::Image] image    the image to convert
    # @param [#to_s] width                the maximum width
    # @param [#to_s] height               the maximum height
    # @yield [MiniMagick::Tool::Mogrify, MiniMagick::Tool::Convert]
    # @return [File, Tempfile]
    def resize_to_limit!(image, width, height)
      _with_minimagick(image) do |img|
        img.combine_options do |cmd|
          yield cmd if block_given?
          cmd.resize "#{width}x#{height}>"
        end
      end
    end
    nondestructive_alias :resize_to_limit, :resize_to_limit!

    # Resize the image to fit within the specified dimensions while retaining
    # the original aspect ratio. The image may be shorter or narrower than
    # specified in the smaller dimension but will not be larger than the
    # specified values.
    #
    # @param [MiniMagick::Image] image    the image to convert
    # @param [#to_s] width                the width to fit into
    # @param [#to_s] height               the height to fit into
    # @yield [MiniMagick::Tool::Mogrify, MiniMagick::Tool::Convert]
    # @return [File, Tempfile]
    def resize_to_fit!(image, width, height)
      _with_minimagick(image) do |img|
        img.combine_options do |cmd|
          yield cmd if block_given?
          cmd.resize "#{width}x#{height}"
        end
      end
    end
    nondestructive_alias :resize_to_fit, :resize_to_fit!

    # Resize the image so that it is at least as large in both dimensions as
    # specified, then crops any excess outside the specified dimensions.
    #
    # The resulting image will always be exactly as large as the specified
    # dimensions.
    #
    # By default, the center part of the image is kept, and the remainder
    # cropped off, but this can be changed via the `gravity` option.
    #
    # @param [MiniMagick::Image] image    the image to convert
    # @param [#to_s] width                the width to fill out
    # @param [#to_s] height               the height to fill out
    # @param [String] gravity             which part of the image to focus on
    # @yield [MiniMagick::Tool::Mogrify, MiniMagick::Tool::Convert]
    # @return [File, Tempfile]
    # @see http://www.imagemagick.org/script/command-line-options.php#gravity
    def resize_to_fill!(image, width, height, gravity: "Center")
      _with_minimagick(image) do |img|
        img.combine_options do |cmd|
          yield cmd if block_given?
          cmd.resize "#{width}x#{height}^"
          cmd.gravity gravity
          cmd.extent "#{width}x#{height}"
        end
      end
    end
    nondestructive_alias :resize_to_fill, :resize_to_fill!

    # Resize the image to fit within the specified dimensions while retaining
    # the original aspect ratio in the same way as {#fill}. Unlike {#fill} it
    # will, if necessary, pad the remaining area with the given color, which
    # defaults to transparent where supported by the image format and white
    # otherwise.
    #
    # The resulting image will always be exactly as large as the specified
    # dimensions.
    #
    # By default, the image will be placed in the center but this can be
    # changed via the `gravity` option.
    #
    # @param [MiniMagick::image] image    the image to convert
    # @param [#to_s] width                the width to fill out
    # @param [#to_s] height               the height to fill out
    # @param [string] background          the color to use as a background
    # @param [string] gravity             which part of the image to focus on
    # @yield [MiniMagick::Tool::Mogrify, MiniMagick::Tool::Convert]
    # @return [File, Tempfile]
    # @see http://www.imagemagick.org/script/color.php
    # @see http://www.imagemagick.org/script/command-line-options.php#gravity
    def resize_and_pad!(image, width, height, background: "transparent", gravity: "Center")
      _with_minimagick(image) do |img|
        img.combine_options do |cmd|
          yield cmd if block_given?
          cmd.resize "#{width}x#{height}"
          if background == "transparent"
            cmd.background "rgba(255, 255, 255, 0.0)"
          else
            cmd.background background
          end
          cmd.gravity gravity
          cmd.extent "#{width}x#{height}"
        end
      end
    end
    nondestructive_alias :resize_and_pad, :resize_and_pad!

    # Convert an image into a MiniMagick::Image for the duration of the block,
    # and at the end return a File object.
    def _with_minimagick(image)
      image = ::MiniMagick::Image.new(image.path, image)
      yield image
      image.instance_variable_get("@tempfile")
    end

    # Creates a copy of the file and stores it into a Tempfile. Works for any
    # IO object that responds to `#read(length = nil, outbuf = nil)`.
    def _copy_to_tempfile(file)
      args = [File.basename(file.path, ".*"), File.extname(file.path)] if file.respond_to?(:path)
      tempfile = Tempfile.new(args || "image", binmode: true)
      IO.copy_stream(file, tempfile.path)
      tempfile
    end
  end
end
