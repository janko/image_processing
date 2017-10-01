require "vips"
require_relative "vips/color"
require_relative "vips/gravity"
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
    # @param [Vips::Image] image    the image to convert
    # @param [String] format        the format to convert to
    # @param [File] destination     the end destination where the image will be safe
    # @return [File, Tempfile]
    def convert(image, format, destination: nil, &block)
      vips_image = ::Vips::Image.new_from_file image.path
      destination_image = destination || _tempfile(".#{format}")
      vips_image.write_to_file(destination_image.path)
      destination_image
    end

    def convert!(image, format, &block)
      destination_path = Pathname(image.path).sub_ext(".#{format}").to_s
      convert(image, format, destination: File.new(destination_path), &block).tap do
        image.close
        File.delete(image.path)
      end
    end

    # Adjusts the image so that its orientation is suitable for viewing.
    #
    # @see http://www.vips.ecs.soton.ac.uk/supported/7.42/doc/html/libvips/libvips-conversion.html#vips-autorot
    # @param [Vips::Image] image    the image to convert
    # @param [File] destination     the end destination where the image will be safe
    # @return [File, Tempfile]
    def auto_orient(image, destination: nil, &block)
      with_ruby_vips(image, destination) do |vips_image|
        vips_image.autorot
      end
    end

    def auto_orient!(image, &block)
      auto_orient(image, destination: image, &block)
    end

    # Resize the image to fit within the specified dimensions while retaining
    # the original aspect ratio. Will only resize the image if it is larger
    # than the specified dimensions. The resulting image may be shorter or
    # narrower than specified in either dimension but will not be larger than
    # the specified values.
    #
    # @param [Vips::Image] image    the image to convert
    # @param [#to_s] width          the maximum width
    # @param [#to_s] height         the maximum height
    # @param [File] destination     the end destination where the image will be safe
    # @return [File, Tempfile]
    def resize_to_limit(image, width, height, destination: nil, &block)
      with_ruby_vips(image, destination) do |vips_image|
        if width < vips_image.width || height < vips_image.height
          resize_image(vips_image, width, height)
        else
          vips_image
        end
      end
    end

    def resize_to_limit!(image, width, height, &block)
      resize_to_limit(image, width, height, destination: image, &block)
    end

    # Resize the image to fit within the specified dimensions while retaining
    # the original aspect ratio. The image may be shorter or narrower than
    # specified in the smaller dimension but will not be larger than the
    # specified values.
    #
    # @param [Vips::Image] image    the image to convert
    # @param [#to_s] width                the width to fit into
    # @param [#to_s] height               the height to fit into
    # @param [File] destination     the end destination where the image will be safe
    # @return [File, Tempfile]
    def resize_to_fit(image, width, height, destination: nil, &block)
      with_ruby_vips(image, destination) do |vips_image|
        resize_image(vips_image, width, height)
      end
    end

    def resize_to_fit!(image, width, height, &block)
      resize_to_fit(image, width, height, destination: image, &block)
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
    # @param [Vips::Image] image    the image to convert
    # @param [#to_s] width                the width to fill out
    # @param [#to_s] height               the height to fill out
    # @param [File] destination     the end destination where the image will be safe
    # @return [File, Tempfile]
    def resize_to_fill(image, width, height, destination: nil, &block)
      with_ruby_vips(image, destination) do |vips_image|
        vips_image = resize_image vips_image, width, height, :max
        extract_area(vips_image, width, height)
      end
    end

    def resize_to_fill!(image, width, height, &block)
      resize_to_fill(image, width, height, destination: image, &block)
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
    # @param [Vips::image] image          the image to convert
    # @param [#to_s] width                the width to fill out
    # @param [#to_s] height               the height to fill out
    # @param [String] background          the color to use as a background
    # @param [String] gravity             which part of the image to focus on
    # @param [File] destination     the end destination where the image will be safe
    # @return [File, Tempfile]
    # @see http://www.imagemagick.org/script/color.php
    # @see http://www.imagemagick.org/script/command-line-options.php#gravity
    def resize_and_pad(image, width, height, background: 'opaque', gravity: 'Center', destination: nil, &block)
      with_ruby_vips(image, destination) do |vips_image|
        vips_image = resize_image vips_image, width, height
        top, left = Gravity.get(vips_image, width, height, gravity)
        vips_image = vips_image.embed(top, left, width, height, {extend: :background, background: Color.get(background)})
        vips_image
      end
    end

    def resize_and_pad!(image, width, height, background: "opaque", gravity: "Center", &block)
      resize_and_pad(image, width, height, background: background, gravity: gravity, destination: image, &block)
    end

    # Crops the image to be the defined area.
    #
    # @param [#to_s] width                the width of the cropped image
    # @param [#to_s] height               the height of the cropped image
    # @param [#to_s] x_offset             the x coordinate where to start cropping
    # @param [#to_s] y_offset             the y coordinate where to start cropping
    # @param [String] gravity             which part of the image to focus on
    # @param [File] destination     the end destination where the image will be safe
    # @yield [Vips::Image]
    # @return [File, Tempfile]
    # @see http://www.imagemagick.org/script/command-line-options.php#gravity
    # @see http://www.vips.ecs.soton.ac.uk/supported/7.42/doc/html/libvips/libvips-conversion.html#vips-crop
    def crop(image, width, height, gravity: 'NorthWest', destination: nil, &block)
      with_ruby_vips(image, destination) do |vips_image|
        top, left = Gravity.get(vips_image, width, height, gravity)
        vips_image.crop top, left, width, height
      end
    end

    def crop!(image, width, height, gravity: "NorthWest", &block)
      crop(image, width, height, gravity: gravity, destination: image, &block)
    end

    # Convert an image into a Vips::Image for the duration of the block,
    # and at the end return a File object.
    def with_ruby_vips(image, destination)
      extension = File.extname(image.path) if image.respond_to?(:path)
      vips_image = ::Vips::Image.new_from_file image.path
      vips_image = yield(vips_image)
      destination ||= _tempfile(extension)
      vips_image.write_to_file(destination.path)
      destination
    end

    def _tempfile(extension)
      Tempfile.new(["image_processing-vips", extension.to_s], binmode: true)
    end

    def resize_image(image, width, height, min_or_max = :min)
      ratio = get_ratio image, width, height, min_or_max
      return image if ratio == 1
      image = if ratio > 1
                image.resize(ratio, kernel: :nearest)
              else
                image.resize(ratio, kernel: :cubic)
              end
      image
    end

    def get_ratio(image, width,height, min_or_max = :min)
      width_ratio = width.to_f / image.width
      height_ratio = height.to_f / image.height
      [width_ratio, height_ratio].send(min_or_max)
    end

    def extract_area(image, width, height)
      if image.width > width
        top = 0
        left = (image.width - width) / 2
      elsif image.height > height
        left = 0
        top = (image.height - height) / 2
      else
        left = 0
        top = 0
      end

      height = image.height if image.height < height
      width = image.width if image.width < width

      image.extract_area(left, top, width, height)
    end
  end
end
