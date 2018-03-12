require "vips"

require "image_processing/vips/color"
require "image_processing/vips/gravity"
require "image_processing/utils"

require "tempfile"

if Gem::Version.new(Vips::VERSION) < Gem::Version.new("2.0.0")
  raise "image_processing requires ruby-vips version >= 2.0.0"
end

module ImageProcessing
  module Vips
    module_function

    # Resize the image to fit within the specified dimensions while retaining
    # the original aspect ratio. Will only resize the image if it is larger
    # than the specified dimensions. The resulting image may be shorter or
    # narrower than specified in either dimension but will not be larger than
    # the specified values.
    #
    # @param [#path, #read] file       the image to convert
    # @param [#to_s] width             the maximum width
    # @param [#to_s] height            the maximum height
    # @param [String] format           file format of the output file
    # @param [Hash] options            options for Vips::Image#thumbnail_image
    # @yield [Vips::Image]
    # @return [Tempfile]
    # @see http://www.rubydoc.info/gems/ruby-vips/Vips/Image#thumbnail_image-instance_method
    def resize_to_limit(file, width, height, format: nil, **options, &block)
      vips(file, format: format) do |vips_image|
        vips_image = yield(vips_image) if block_given?
        vips_image.thumbnail_image(width, height: height, size: :down, **options)
      end
    end

    # Resize the image to fit within the specified dimensions while retaining
    # the original aspect ratio. The image may be shorter or narrower than
    # specified in the smaller dimension but will not be larger than the
    # specified values.
    #
    # @param [#path, #read] file       the image to convert
    # @param [#to_s] width             the width to fit into
    # @param [#to_s] height            the height to fit into
    # @param [String] format           file format of the output file
    # @param [Hash] options            options for Vips::Image#thumbnail_image
    # @yield [Vips::Image]
    # @return [Tempfile]
    # @see http://www.rubydoc.info/gems/ruby-vips/Vips/Image#thumbnail_image-instance_method
    def resize_to_fit(file, width, height, format: nil, **options, &block)
      vips(file, format: format) do |vips_image|
        vips_image = yield(vips_image) if block_given?
        vips_image.thumbnail_image(width, height: height, **options)
      end
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
    # @param [#path, #read] file       the image to convert
    # @param [#to_s] width             the width to fill out
    # @param [#to_s] height            the height to fill out
    # @param [String] format           file format of the output file
    # @param [Hash] options            options for Vips::Image#thumbnail_image
    # @yield [Vips::Image]
    # @return [Tempfile]
    # @see http://www.rubydoc.info/gems/ruby-vips/Vips/Image#thumbnail_image-instance_method
    def resize_to_fill(file, width, height, crop: :centre, format: nil, **options, &block)
      vips(file, format: format) do |vips_image|
        vips_image = yield(vips_image) if block_given?
        vips_image.thumbnail_image(width, height: height, crop: crop, **options)
      end
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
    # @param [#path, #read] file       the image to convert
    # @param [#to_s] width             the width to fill out
    # @param [#to_s] height            the height to fill out
    # @param [String] background       the color to use as a background
    # @param [String] gravity          which part of the image to focus on
    # @param [String] format           file format of the output file
    # @param [Hash] options            options for Vips::Image#thumbnail_image
    # @yield [Vips::Image]
    # @return [Tempfile]
    # @see http://www.rubydoc.info/gems/ruby-vips/Vips/Image#thumbnail_image-instance_method
    # @see http://www.imagemagick.org/script/color.php
    # @see http://www.imagemagick.org/script/command-line-options.php#gravity
    def resize_and_pad(file, width, height, background: 'opaque', gravity: 'Center', format: nil, **options, &block)
      vips(file, format: format) do |vips_image|
        vips_image = yield(vips_image) if block_given?
        vips_image = vips_image.thumbnail_image(width, height: height, **options)
        top, left = Gravity.get(vips_image, width, height, gravity)
        vips_image = vips_image.embed(top, left, width, height, extend: :background, background: Color.get(background))
        vips_image
      end
    end

    # Crops the image to be the defined area.
    #
    # @param [#path, #read] file       the image to convert
    # @param [#to_s] width             the width of the cropped image
    # @param [#to_s] height            the height of the cropped image
    # @param [#to_s] x_offset          the x coordinate where to start cropping
    # @param [#to_s] y_offset          the y coordinate where to start cropping
    # @param [String] gravity          which part of the image to focus on
    # @param [String] format           file format of the output file
    # @yield [Vips::Image]
    # @return [Tempfile]
    # @see http://www.imagemagick.org/script/command-line-options.php#gravity
    # @see http://jcupitt.github.io/libvips/API/current/libvips-conversion.html#vips-crop
    def crop(file, width, height, gravity: 'NorthWest', format: nil, &block)
      vips(file, format: format) do |vips_image|
        vips_image = yield(vips_image) if block_given?
        top, left = Gravity.get(vips_image, width, height, gravity)
        vips_image.crop top, left, width, height
      end
    end

    # Converts an image into a Vips::Image for the duration of the block,
    # and returns the processed file.
    #
    # @param [#path, #read] file        file to be processed
    # @param [String] format            file format of the output file
    # @param [Hash] options             options for Vips::Image.new_from_file
    # @yield [Vips::Image]
    # @return [Tempfile]
    # @see http://www.rubydoc.info/gems/ruby-vips/Vips/Image#new_from_file-class_method
    def vips(file, format: nil, **options, &block)
      unless file.respond_to?(:path)
        return Utils.copy_to_tempfile(file) { |tempfile|
          vips(tempfile, format: format, **options, &block)
        }
      end

      vips_image = ::Vips::Image.new_from_file(file.path, fail: true, **options)
      vips_image = vips_image.autorot
      vips_image = yield(vips_image) if block_given?

      format ||= File.extname(file.path)[1..-1] || "png"
      result = Tempfile.new(["image_processing-vips", ".#{format}"], binmode: true)

      vips_image.write_to_file(result.path)
      result.open # refresh content

      result
    end
  end
end
