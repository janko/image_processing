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

    # Changes the image encoding format to the given format
    # Libvips convert the file automatically based on the name
    # since we want the user to have a destructive and a non destructive method
    # using the destructive method will cause the original file to be deleted
    #
    # @param [#path, #read] file       the image to convert
    # @param [String] format           the format to convert to
    # @yield [Vips::Image]
    # @return [Tempfile]
    def convert(file, format, &block)
      with_vips(file, extension: ".#{format}", &block)
    end

    # Adjusts the image so that its orientation is suitable for viewing.
    #
    # @param [#path, #read] file       the image to convert
    # @yield [Vips::Image]
    # @return [Tempfile]
    # @see http://jcupitt.github.io/libvips/API/current/libvips-conversion.html#vips-autorot
    def auto_orient(file, &block)
      with_vips(file) do |vips_image|
        vips_image = yield(vips_image) if block_given?
        vips_image.autorot
      end
    end

    # Resize the image to fit within the specified dimensions while retaining
    # the original aspect ratio. Will only resize the image if it is larger
    # than the specified dimensions. The resulting image may be shorter or
    # narrower than specified in either dimension but will not be larger than
    # the specified values.
    #
    # @param [#path, #read] file       the image to convert
    # @param [#to_s] width             the maximum width
    # @param [#to_s] height            the maximum height
    # @param [Hash] options            options for Vips::Image#thumbnail_image
    # @yield [Vips::Image]
    # @return [Tempfile]
    # @see http://www.rubydoc.info/gems/ruby-vips/Vips/Image#thumbnail_image-instance_method
    def resize_to_limit(file, width, height, auto_rotate: true, **options, &block)
      with_vips(file) do |vips_image|
        vips_image = yield(vips_image) if block_given?
        vips_image.thumbnail_image(width, height: height, size: :down, auto_rotate: auto_rotate, **options)
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
    # @param [Hash] options            options for Vips::Image#thumbnail_image
    # @yield [Vips::Image]
    # @return [Tempfile]
    # @see http://www.rubydoc.info/gems/ruby-vips/Vips/Image#thumbnail_image-instance_method
    def resize_to_fit(file, width, height, auto_rotate: true, **options, &block)
      with_vips(file) do |vips_image|
        vips_image = yield(vips_image) if block_given?
        vips_image.thumbnail_image(width, height: height, auto_rotate: auto_rotate, **options)
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
    # @param [Hash] options            options for Vips::Image#thumbnail_image
    # @yield [Vips::Image]
    # @return [Tempfile]
    # @see http://www.rubydoc.info/gems/ruby-vips/Vips/Image#thumbnail_image-instance_method
    def resize_to_fill(file, width, height, crop: :centre, auto_rotate: true, **options, &block)
      with_vips(file) do |vips_image|
        vips_image = yield(vips_image) if block_given?
        vips_image.thumbnail_image(width, height: height, crop: crop, auto_rotate: auto_rotate, **options)
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
    # @param [#path, #read] file        the image to convert
    # @param [#to_s] width              the width to fill out
    # @param [#to_s] height             the height to fill out
    # @param [String] background        the color to use as a background
    # @param [String] gravity           which part of the image to focus on
    # @param [Hash] options             options for Vips::Image#thumbnail_image
    # @yield [Vips::Image]
    # @return [Tempfile]
    # @see http://www.rubydoc.info/gems/ruby-vips/Vips/Image#thumbnail_image-instance_method
    # @see http://www.imagemagick.org/script/color.php
    # @see http://www.imagemagick.org/script/command-line-options.php#gravity
    def resize_and_pad(file, width, height, background: 'opaque', gravity: 'Center', auto_rotate: true, **options, &block)
      with_vips(file) do |vips_image|
        vips_image = yield(vips_image) if block_given?
        vips_image = vips_image.thumbnail_image(width, height: height, auto_rotate: auto_rotate, **options)
        top, left = Gravity.get(vips_image, width, height, gravity)
        vips_image = vips_image.embed(top, left, width, height, extend: :background, background: Color.get(background))
        vips_image
      end
    end

    # Crops the image to be the defined area.
    #
    # @param [#path, #read] file        the image to convert
    # @param [#to_s] width              the width of the cropped image
    # @param [#to_s] height             the height of the cropped image
    # @param [#to_s] x_offset           the x coordinate where to start cropping
    # @param [#to_s] y_offset           the y coordinate where to start cropping
    # @param [String] gravity           which part of the image to focus on
    # @yield [Vips::Image]
    # @return [Tempfile]
    # @see http://www.imagemagick.org/script/command-line-options.php#gravity
    # @see http://jcupitt.github.io/libvips/API/current/libvips-conversion.html#vips-crop
    def crop(file, width, height, gravity: 'NorthWest', &block)
      with_vips(file) do |vips_image|
        vips_image = yield(vips_image) if block_given?
        top, left = Gravity.get(vips_image, width, height, gravity)
        vips_image.crop top, left, width, height
      end
    end

    # Convert an image into a Vips::Image for the duration of the block,
    # and at the end return a File object.
    def with_vips(file, extension: nil, &block)
      unless file.respond_to?(:path)
        return Utils.copy_to_tempfile(file) { |tempfile|
          with_vips(tempfile, extension: extension, &block)
        }
      end

      vips_image = ::Vips::Image.new_from_file(file.path, fail: true)
      vips_image = yield(vips_image) if block_given?

      extension ||= File.extname(file.path)
      extension   = ".png" if extension.empty? # save in PNG format by default
      result = Tempfile.new(["image_processing-vips", extension], binmode: true)

      vips_image.write_to_file(result.path)
      result.open # refresh content

      result
    end
  end
end
