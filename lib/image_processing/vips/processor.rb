gem "ruby-vips", "~> 2.0"
require "vips"
fail "image_processing/vips requires libvips 8.6+" unless Vips.at_least_libvips?(8, 6)

require "image_processing/vips/color"
require "tempfile"

module ImageProcessing
  module Vips
    class Processor
      # libvips has this arbitrary number as a sanity-check upper bound on image
      # size.
      MAX_COORD = 10_000_000

      def initialize(source)
        fail Error, "source file not provided" unless source
        fail Error, "source file doesn't respond to #path" unless source.respond_to?(:path) || source.is_a?(::Vips::Image)

        @source = source
      end

      def apply_operation(name, image, *args)
        if respond_to?(name)
          public_send(name, image, *args)
        else
          result = image.send(name, *args)
          result.is_a?(::Vips::Image) ? result : image
        end
      end

      def resize_to_limit(image, width, height, **options)
        width, height = default_dimensions(width, height)
        image.thumbnail_image(width, height: height, size: :down, **options)
      end

      def resize_to_fit(image, width, height, **options)
        width, height = default_dimensions(width, height)
        image.thumbnail_image(width, height: height, **options)
      end

      def resize_to_fill(image, width, height, **options)
        image.thumbnail_image(width, height: height, crop: :centre, **options)
      end

      def resize_and_pad(image, width, height, background: "opaque", gravity: "centre", **options)
        image.thumbnail_image(width, height: height, **options)
          .gravity(gravity, width, height, extend: :background, background: Color.get(background))
      end

      def load_image(**options)
        return @source if @source.is_a?(::Vips::Image)

        ::Vips::Image.new_from_file(@source.path, fail: true, **options)
      end

      def save_image(image, format, **options)
        format ||= default_format
        result = Tempfile.new(["image_processing-vips", ".#{format}"], binmode: true)

        image.write_to_file(result.path, **options)
        result.open # refresh content

        result
      end

      private

      def default_dimensions(width, height)
        raise Error, "either width or height must be specified" unless width || height

        [width || MAX_COORD, height || MAX_COORD]
      end

      def default_format
        File.extname(original_path.to_s)[1..-1] || "jpg"
      end

      def original_path
        @source.path if @source.respond_to?(:path)
      end
    end
  end
end
