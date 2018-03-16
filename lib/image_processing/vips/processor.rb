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

      def apply_operation(name, image, *args)
        if respond_to?(name)
          public_send(name, image, *args)
        else
          image.send(name, *args)
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

      def load_image(file, **options)
        fail Error, "source file not provided" unless file
        fail Error, "source file doesn't respond to #path" unless file.respond_to?(:path) || file.is_a?(::Vips::Image)

        return file if file.is_a?(::Vips::Image)

        ::Vips::Image.new_from_file(file.path, fail: true, **options)
      end

      def save_image(image, format, **options)
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
    end
  end
end
