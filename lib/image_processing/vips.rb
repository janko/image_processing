gem "ruby-vips", "~> 2.0"
require "vips"

require "image_processing"

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
      IMAGE_CLASS = ::Vips::Image
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

      def resize_and_pad(image, width, height, gravity: "centre", extend: nil, background: nil, alpha: nil, **options)
        embed_options = { extend: extend, background: background }
        embed_options.reject! { |name, value| value.nil? }

        image = image.thumbnail_image(width, height: height, **options)
        image = image.bandjoin(255) if alpha && image.bands == 3
        image.gravity(gravity, width, height, **embed_options)
      end

      def load_image(path_or_image, autorot: true, **options)
        if path_or_image.is_a?(::Vips::Image)
          image = path_or_image
        else
          source_path = path_or_image
          loader  = ::Vips.vips_foreign_find_load(source_path)
          options = select_valid_options(loader, options) if loader

          image = ::Vips::Image.new_from_file(source_path, fail: true, **options)
        end

        image = image.autorot if autorot
        image
      end

      def save_image(image, destination_path, **options)
        saver   = ::Vips.vips_foreign_find_save(destination_path)
        options = select_valid_options(saver, options) if saver

        image.write_to_file(destination_path, **options)
      end

      private

      def default_dimensions(width, height)
        raise Error, "either width or height must be specified" unless width || height

        [width || MAX_COORD, height || MAX_COORD]
      end

      def select_valid_options(operation_name, options)
        operation = ::Vips::Operation.new(operation_name)

        operation_options = operation.get_construct_args
          .select { |name, flags| (flags & ::Vips::ARGUMENT_INPUT)    != 0 }
          .select { |name, flags| (flags & ::Vips::ARGUMENT_REQUIRED) == 0 }
          .map(&:first).map(&:to_sym)

        options.select { |name, value| operation_options.include?(name) }
      end
    end

    extend Chainable
  end
end
