gem "ruby-vips", "~> 2.0"
require "vips"

require "image_processing"
require "image_processing/vips/color"

require "tempfile"

fail "image_processing/vips requires libvips 8.6+" unless Vips.at_least_libvips?(8, 6)

module ImageProcessing
  module Vips
    def self.valid_image?(file)
      ::Vips::Image.new_from_file(file.path, access: :sequential, fail: true).avg
      true
    rescue ::Vips::Error
      false
    end

    class Processor
      # libvips has this arbitrary number as a sanity-check upper bound on image
      # size.
      MAX_COORD = 10_000_000

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

      def load_image(file, **options)
        return file if file.is_a?(::Vips::Image)

        fail Error, "source file needs to respond to #path or be a Vips::Image" unless file.respond_to?(:path)

        ::Vips::Image.new_from_file(file.path, fail: true, **options)
      end

      def save_image(image, destination, **options)
        image.write_to_file(destination.path, **options)
      end

      private

      def default_dimensions(width, height)
        raise Error, "either width or height must be specified" unless width || height

        [width || MAX_COORD, height || MAX_COORD]
      end
    end

    extend Chainable
  end
end
