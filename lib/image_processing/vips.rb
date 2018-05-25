require "vips"
require "image_processing"

fail "image_processing/vips requires libvips 8.6+" unless Vips.at_least_libvips?(8, 6)

module ImageProcessing
  module Vips
    extend Chainable

    def self.valid_image?(file)
      ::Vips::Image.new_from_file(file.path, access: :sequential).avg
      true
    rescue ::Vips::Error
      false
    end

    class Processor < ImageProcessing::Processor
      IMAGE_CLASS  = ::Vips::Image
      # default sharpening mask that provides a fast and mild sharpen
      SHARPEN_MASK = ::Vips::Image.new_from_array [[-1, -1, -1],
                                                   [-1, 32, -1],
                                                   [-1, -1, -1]], 24

      def apply_operation(name, image, *args)
        result = super
        result.is_a?(::Vips::Image) ? result : image
      end

      def resize_to_limit(image, width, height, **options)
        width, height = default_dimensions(width, height)
        thumbnail(image, width, height, size: :down, **options)
      end

      def resize_to_fit(image, width, height, **options)
        width, height = default_dimensions(width, height)
        thumbnail(image, width, height, **options)
      end

      def resize_to_fill(image, width, height, **options)
        thumbnail(image, width, height, crop: :centre, **options)
      end

      def resize_and_pad(image, width, height, gravity: "centre", extend: nil, background: nil, alpha: nil, **options)
        embed_options = { extend: extend, background: background }
        embed_options.reject! { |name, value| value.nil? }

        image = thumbnail(image, width, height, **options)
        image = image.add_alpha if alpha && !image.has_alpha?
        image.gravity(gravity, width, height, **embed_options)
      end

      def rotate(image, degrees, **options)
        if degrees % 90 == 0
          image.rot(:"d#{degrees % 360}")
        else
          image.similarity(angle: degrees, **options)
        end
      end

      def load_image(path_or_image, autorot: true, **options)
        if path_or_image.is_a?(::Vips::Image)
          image = path_or_image
        else
          source_path = path_or_image
          options     = select_valid_loader_options(source_path, options)

          image = ::Vips::Image.new_from_file(source_path, **options)
        end

        image = image.autorot if autorot && !options.key?(:autorotate)
        image
      end

      def save_image(image, destination_path, quality: nil, **options)
        options = options.merge(Q: quality) if quality
        options = select_valid_saver_options(destination_path, options)

        image.write_to_file(destination_path, **options)
      end

      private

      def thumbnail(image, width, height, sharpen: SHARPEN_MASK, **options)
        image = image.thumbnail_image(width, height: height, **options)
        image = image.conv(sharpen) if sharpen
        image
      end

      def default_dimensions(width, height)
        raise Error, "either width or height must be specified" unless width || height

        [width || ::Vips::MAX_COORD, height || ::Vips::MAX_COORD]
      end

      def select_valid_loader_options(source_path, options)
        loader = ::Vips.vips_foreign_find_load(source_path)
        loader ? select_valid_options(loader, options) : options
      end

      def select_valid_saver_options(destination_path, options)
        saver = ::Vips.vips_foreign_find_save(destination_path)
        saver ? select_valid_options(saver, options) : options
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
  end
end
