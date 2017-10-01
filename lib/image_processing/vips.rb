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

    def self.nondestructive_alias(name, original)
      define_method(name) do |image, *args, **options, &block|
        keyword_arguments = options.merge(destructive: false)
        send(original, image, *args, **keyword_arguments, &block)
      end
      module_function name
    end

    # Changes the image encoding format to the given format
    # Libvips convert the file automatically based on the name
    # since we want the user to have a destructive and a non destructive method
    # using the destructive method will cause the original file to be deleted
    #
    # @param [Vips::Image] image    the image to convert
    # @param [String] format        the format to convert to
    # @return [File, Tempfile]
    def convert!(image, format, &block)
      vips_image = ::Vips::Image.new_from_file image.path
      new_name = tmp_name(image.path, ".#{format}")
      vips_image.write_to_file(new_name)
      File.delete(image.path)
      File.new(new_name)
    end

    def convert(image, format, &block)
      vips_image = ::Vips::Image.new_from_file image.path
      tmp_name = tmp_name(image.path, "_tmp.#{format}")
      vips_image.write_to_file(tmp_name)
      File.new(tmp_name)
    end

    # Adjusts the image so that its orientation is suitable for viewing.
    #
    # @see http://www.vips.ecs.soton.ac.uk/supported/7.42/doc/html/libvips/libvips-conversion.html#vips-autorot
    # @param [Vips::Image] image    the image to convert
    # @yield [Vips::Image]
    # @return [File, Tempfile]
    def auto_orient!(image, destructive: true)
      with_ruby_vips(image, destructive) do |img|
        img.autorot
      end
    end
    nondestructive_alias :auto_orient, :auto_orient!

    # Resize the image to fit within the specified dimensions while retaining
    # the original aspect ratio. Will only resize the image if it is larger
    # than the specified dimensions. The resulting image may be shorter or
    # narrower than specified in either dimension but will not be larger than
    # the specified values.
    #
    # @param [Vips::Image] image    the image to convert
    # @param [#to_s] width          the maximum width
    # @param [#to_s] height         the maximum height
    # @yield [Vips::Image]
    # @return [File, Tempfile]
    def resize_to_limit!(image, width, height, destructive: true)
      with_ruby_vips(image, destructive) do |img|
        if width < img.width || height < img.height
          resize_image(img, width, height)
        else
          img
        end
      end
    end
    nondestructive_alias :resize_to_limit, :resize_to_limit!

    # Resize the image to fit within the specified dimensions while retaining
    # the original aspect ratio. The image may be shorter or narrower than
    # specified in the smaller dimension but will not be larger than the
    # specified values.
    #
    # @param [Vips::Image] image    the image to convert
    # @param [#to_s] width                the width to fit into
    # @param [#to_s] height               the height to fit into
    # @yield [Vips::Image]
    # @return [File, Tempfile]
    def resize_to_fit!(image, width, height, destructive: true)
      with_ruby_vips(image, destructive) do |img|
        resize_image(img, width, height)
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
    # @param [Vips::Image] image    the image to convert
    # @param [#to_s] width                the width to fill out
    # @param [#to_s] height               the height to fill out
    # @param [String] gravity             which part of the image to focus on
    # @yield [Vips::Tool::Mogrify]
    # @return [File, Tempfile]
    def resize_to_fill!(image, width, height, destructive: true)
      with_ruby_vips(image, destructive) do |img|
        img = resize_image img, width, height, :max
        extract_area(img, width, height)
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
    # @param [Vips::image] image          the image to convert
    # @param [#to_s] width                the width to fill out
    # @param [#to_s] height               the height to fill out
    # @param [string] background          the color to use as a background
    # @param [string] gravity             which part of the image to focus on
    # @yield [Vips::Tool::Mogrify]
    # @return [File, Tempfile]
    # @see http://www.imagemagick.org/script/color.php
    # @see http://www.imagemagick.org/script/command-line-options.php#gravity
    def resize_and_pad!(image, width, height, background: "opaque", gravity: "Center", destructive: true)
      with_ruby_vips(image, destructive) do |img|
        img = resize_image img, width, height
        top, left = Gravity.get(img, width, height, gravity)
        img = img.embed(top, left, width, height, {extend: :background, background: Color.get(background)})
        img
      end
    end
    nondestructive_alias :resize_and_pad, :resize_and_pad!

    # Crops the image to be the defined area.
    #
    # @param [#to_s] width                the width of the cropped image
    # @param [#to_s] height               the height of the cropped image
    # @param [#to_s] x_offset             the x coordinate where to start cropping
    # @param [#to_s] y_offset             the y coordinate where to start cropping
    # @param [string] gravity             which part of the image to focus on
    # @yield [Vips::Image]
    # @return [File, Tempfile]
    # @see http://www.imagemagick.org/script/command-line-options.php#gravity
    # @see http://www.vips.ecs.soton.ac.uk/supported/7.42/doc/html/libvips/libvips-conversion.html#vips-crop
    def crop!(image, width, height, gravity: "NorthWest", destructive: true)
      with_ruby_vips(image, destructive) do |img|
        top, left = Gravity.get(img, width, height, gravity)
        img.crop top, left, width, height
      end
    end
    nondestructive_alias :crop, :crop!

    # Convert an image into a Vips::Image for the duration of the block,
    # and at the end return a File object.
    def with_ruby_vips(image, destructive)
      vips_image = yield ::Vips::Image.new_from_file image.path
      path_to_write = if destructive
                        image.path
                      else
                        tmp_name(image.path)
                      end
      vips_image.write_to_file(path_to_write)
      File.new(path_to_write)
    end

    # Creates a copy of the file and stores it into a Tempfile. Works for any
    # IO object that responds to `#read(length = nil, outbuf = nil)`.
    def _copy_to_tempfile(file)
      extension = File.extname(file.path) if file.respond_to?(:path)
      tempfile = Tempfile.new(["vips", extension.to_s], binmode: true)
      IO.copy_stream(file, tempfile.path)
      file.rewind
      tempfile
    end

    def tmp_name(path, ext='_tmp\1')
      ext_regex = /(\.[[:alnum:]]+)$/
      path.sub(ext_regex, ext)
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
