require "vips"
require "image_processing/vips/color"
require "image_processing/vips/gravity"
require "image_processing/vips/utils"
require "tempfile"

if Gem::Version.new(Vips::VERSION) < Gem::Version.new("2.0.0")
  raise "image_processing requires ruby-vips version >= 2.0.0"
end

module ImageProcessing
  module Vips
    module_function

    # Changes the image encoding format to the given format
    # Libvips convert the file automatically based on the name
    # since we want the user to have a destructive and a non destructive method
    # using the destructive method will cause the original file to be deleted
    #
    # @param [File, Tempfile] file     the image to convert
    # @param [String] format           the format to convert to
    # @param [Path] destination_path   the end destination where the image will be safe
    # @return [File, Tempfile]
    def convert(file, format, destination_path: nil, &block)
      with_ruby_vips(file, destination_path, extension: ".#{format}")
    end

    def convert!(file, format, &block)
      destination_path = Pathname(file.path).sub_ext(".#{format}").to_s
      convert(file, format, destination_path: destination_path).tap do
        file.close
        File.delete(file.path)
      end
    end

    # Adjusts the image so that its orientation is suitable for viewing.
    #
    # @param [File, Tempfile] file     the image to convert
    # @param [Path] destination_path   the end destination where the image will be safe
    # @return [File, Tempfile]
    # @see http://www.vips.ecs.soton.ac.uk/supported/7.42/doc/html/libvips/libvips-conversion.html#vips-autorot
    def auto_orient(file, destination_path: nil, &block)
      with_ruby_vips(file, destination_path) do |vips_image|
        vips_image.autorot
      end
    end

    def auto_orient!(file, &block)
      auto_orient(file, destination_path: file.path, &block)
    end

    # Resize the image to fit within the specified dimensions while retaining
    # the original aspect ratio. Will only resize the image if it is larger
    # than the specified dimensions. The resulting image may be shorter or
    # narrower than specified in either dimension but will not be larger than
    # the specified values.
    #
    # @param [File, Tempfile] file     the image to convert
    # @param [#to_s] width             the maximum width
    # @param [#to_s] height            the maximum height
    # @param [Path] destination_path   the end destination where the image will be safe
    # @return [File, Tempfile]
    def resize_to_limit(file, width, height, destination_path: nil, &block)
      with_ruby_vips(file, destination_path) do |vips_image|
        if width < vips_image.width || height < vips_image.height
          Utils.resize_image(vips_image, width, height)
        else
          vips_image
        end
      end
    end

    def resize_to_limit!(file, width, height, &block)
      resize_to_limit(file, width, height, destination_path: file.path, &block)
    end

    # Resize the image to fit within the specified dimensions while retaining
    # the original aspect ratio. The image may be shorter or narrower than
    # specified in the smaller dimension but will not be larger than the
    # specified values.
    #
    # @param [File, Tempfile] file     the image to convert
    # @param [#to_s] width             the width to fit into
    # @param [#to_s] height            the height to fit into
    # @param [Path] destination_path   the end destination where the image will be safe
    # @return [File, Tempfile]
    def resize_to_fit(file, width, height, destination_path: nil, &block)
      with_ruby_vips(file, destination_path) do |vips_image|
        Utils.resize_image(vips_image, width, height)
      end
    end

    def resize_to_fit!(file, width, height, &block)
      resize_to_fit(file, width, height, destination_path: file.path, &block)
    end

    # Resize the image so that it is at least as large in both dimensions as
    # specified, then crops any excess outside the specified dimensions.
    #
    # The resulting image will always be exactly as large as the specified
    # dimensions.
    #
    # By default, the center part of the image is kept, and the remainder
    # cropped off, but this can be changed via the `gravity` option.
    #
    # @param [File, Tempfile] file     the image to convert
    # @param [#to_s] width             the width to fill out
    # @param [#to_s] height            the height to fill out
    # @param [Path] destination_path   the end destination where the image will be safe
    # @return [File, Tempfile]
    def resize_to_fill(file, width, height, destination_path: nil, &block)
      with_ruby_vips(file, destination_path) do |vips_image|
        vips_image = Utils.resize_image vips_image, width, height, :max
        Utils.extract_area(vips_image, width, height)
      end
    end

    def resize_to_fill!(file, width, height, &block)
      resize_to_fill(file, width, height, destination_path: file.path, &block)
    end

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
    # @param [File, Tempfile] file      the image to convert
    # @param [#to_s] width              the width to fill out
    # @param [#to_s] height             the height to fill out
    # @param [String] background        the color to use as a background
    # @param [String] gravity           which part of the image to focus on
    # @param [Path] destination_path    the end destination where the image will be safe
    # @return [File, Tempfile]
    # @see http://www.imagemagick.org/script/color.php
    # @see http://www.imagemagick.org/script/command-line-options.php#gravity
    def resize_and_pad(file, width, height, background: 'opaque', gravity: 'Center', destination_path: nil, &block)
      with_ruby_vips(file, destination_path) do |vips_image|
        vips_image = Utils.resize_image vips_image, width, height
        top, left = Gravity.get(vips_image, width, height, gravity)
        vips_image = vips_image.embed(top, left, width, height, {extend: :background, background: Color.get(background)})
        vips_image
      end
    end

    def resize_and_pad!(file, width, height, background: "opaque", gravity: "Center", &block)
      resize_and_pad(file, width, height, background: background, gravity: gravity, destination_path: file.path, &block)
    end

    # Crops the image to be the defined area.
    #
    # @param [File, Tempfile] file      the image to convert
    # @param [#to_s] width              the width of the cropped image
    # @param [#to_s] height             the height of the cropped image
    # @param [#to_s] x_offset           the x coordinate where to start cropping
    # @param [#to_s] y_offset           the y coordinate where to start cropping
    # @param [String] gravity           which part of the image to focus on
    # @param [Path] destination_path    the end destination where the image will be safe
    # @return [File, Tempfile]
    # @see http://www.imagemagick.org/script/command-line-options.php#gravity
    # @see http://www.vips.ecs.soton.ac.uk/supported/7.42/doc/html/libvips/libvips-conversion.html#vips-crop
    def crop(file, width, height, gravity: 'NorthWest', destination_path: nil, &block)
      with_ruby_vips(file, destination_path) do |vips_image|
        top, left = Gravity.get(vips_image, width, height, gravity)
        vips_image.crop top, left, width, height
      end
    end

    def crop!(file, width, height, gravity: "NorthWest", &block)
      crop(file, width, height, gravity: gravity, destination_path: file.path, &block)
    end

    # Convert an image into a Vips::Image for the duration of the block,
    # and at the end return a File object.
    def with_ruby_vips(file, destination_path = nil, extension: nil)
      file_extension = extension || File.extname(file.path)
      vips_image = ::Vips::Image.new_from_file file.path
      vips_image = yield(vips_image) if block_given?
      destination_file = Utils.destination_file(destination_path, file_extension)
      vips_image.write_to_file(destination_file.path)
      destination_file
    end
  end
end
