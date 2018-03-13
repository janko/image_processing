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
    # @param [Integer] width           the maximum width
    # @param [Integer] height          the maximum height
    # @param [Hash] thumbnail          options for Vips::Image#thumbnail_image
    # @param [Hash] options            options for #vips
    # @yield [Vips::Image]
    # @return [Tempfile]
    # @see http://www.rubydoc.info/gems/ruby-vips/Vips/Image#thumbnail_image-instance_method
    def resize_to_limit(file, width, height, thumbnail: {}, **options, &block)
      vips(file, **options) do |vips_image|
        vips_image = yield(vips_image) if block_given?
        width, height = Utils.infer_dimensions([width, height], vips_image.size)
        vips_image.thumbnail_image(width, height: height, size: :down, **thumbnail)
      end
    end

    # Resize the image to fit within the specified dimensions while retaining
    # the original aspect ratio. The image may be shorter or narrower than
    # specified in the smaller dimension but will not be larger than the
    # specified values.
    #
    # @param [#path, #read] file       the image to convert
    # @param [Integer] width           the width to fit into
    # @param [Integer] height          the height to fit into
    # @param [Hash] thumbnail          options for Vips::Image#thumbnail_image
    # @param [Hash] options            options for #vips
    # @yield [Vips::Image]
    # @return [Tempfile]
    # @see http://www.rubydoc.info/gems/ruby-vips/Vips/Image#thumbnail_image-instance_method
    def resize_to_fit(file, width, height, thumbnail: {}, **options, &block)
      vips(file, **options) do |vips_image|
        vips_image = yield(vips_image) if block_given?
        width, height = Utils.infer_dimensions([width, height], vips_image.size)
        vips_image.thumbnail_image(width, height: height, **thumbnail)
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
    # @param [Integer] width           the width to fill out
    # @param [Integer] height          the height to fill out
    # @param [Hash] thumbnail          options for Vips::Image#thumbnail_image
    # @param [Hash] options            options for #vips
    # @yield [Vips::Image]
    # @return [Tempfile]
    # @see http://www.rubydoc.info/gems/ruby-vips/Vips/Image#thumbnail_image-instance_method
    def resize_to_fill(file, width, height, thumbnail: {}, **options, &block)
      vips(file, **options) do |vips_image|
        vips_image = yield(vips_image) if block_given?
        vips_image.thumbnail_image(width, height: height, crop: :centre, **thumbnail)
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
    # @param [Integer] width           the width to fill out
    # @param [Integer] height          the height to fill out
    # @param [String] background       the color to use as a background
    # @param [String] gravity          which part of the image to focus on
    # @param [Hash] thumbnail          options for Vips::Image#thumbnail_image
    # @param [Hash] options            options for #vips
    # @yield [Vips::Image]
    # @return [Tempfile]
    # @see http://www.rubydoc.info/gems/ruby-vips/Vips/Image#thumbnail_image-instance_method
    # @see http://www.imagemagick.org/script/color.php
    # @see http://www.imagemagick.org/script/command-line-options.php#gravity
    def resize_and_pad(file, width, height, background: "opaque", gravity: "Center", thumbnail: {}, **options, &block)
      vips(file, **options) do |vips_image|
        vips_image = yield(vips_image) if block_given?
        vips_image = vips_image.thumbnail_image(width, height: height, **thumbnail)
        left, top = Gravity.get_coords(vips_image, width, height, gravity)
        vips_image = vips_image.embed(left, top, width, height, extend: :background, background: Color.get(background))
        vips_image
      end
    end

    # Converts an image into a Vips::Image for the duration of the block,
    # and returns the processed file.
    #
    # @param [#path, #read] file        file to be processed
    # @param [String] format            format of the output file
    # @param [Hash] loader              options for Vips::Image.new_from_file
    # @param [Hash] saver               options for Vips::Image#write_to_file
    # @yield [Vips::Image]
    # @return [Tempfile]
    # @see http://www.rubydoc.info/gems/ruby-vips/Vips/Image#new_from_file-class_method
    # @see http://www.rubydoc.info/gems/ruby-vips/Vips/Image#write_to_file-instance_method
    def vips(file, format: nil, loader: {}, saver: {}, &block)
      unless file.respond_to?(:path)
        return Utils.copy_to_tempfile(file) { |tempfile|
          vips(tempfile, format: format, loader: loader, saver: saver, &block)
        }
      end

      vips_image = vips_load(file, **loader)
      vips_image = yield(vips_image) if block_given?

      format ||= File.extname(file.path)[1..-1]
      vips_save(vips_image, format: format, **saver)
    end

    # Loads the image from file path and applies autorotation.
    #
    # @param [#path] file               file to load
    # @param [Hash] options             options for Vips::Image.new_from_file
    # @return [Vips::Image]
    # @see http://www.rubydoc.info/gems/ruby-vips/Vips/Image#new_from_file-class_method
    def vips_load(file, **options)
      vips_image = ::Vips::Image.new_from_file(file.path, fail: true, **options)
      vips_image.autorot
    end

    # Writes the image into a temporary file and returns it.
    #
    # @param [Vips::Image] vips_image   image to save to disk
    # @param [format]                   format of the output file
    # @param [Hash] options             options for Vips::Image#write_to_file
    # @return [Tempfile]
    # @see http://www.rubydoc.info/gems/ruby-vips/Vips/Image#write_to_file-instance_method
    def vips_save(vips_image, format: nil, **options)
      format ||= "jpg"
      result   = Tempfile.new(["image_processing-vips", ".#{format}"], binmode: true)

      vips_image.write_to_file(result.path, **options)
      result.open # refresh content

      result
    end
  end
end
