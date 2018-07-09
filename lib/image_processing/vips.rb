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
      accumulator :image, ::Vips::Image

      # default sharpening mask that provides a fast and mild sharpen
      SHARPEN_MASK = ::Vips::Image.new_from_array [[-1, -1, -1],
                                                   [-1, 32, -1],
                                                   [-1, -1, -1]], 24


      def self.load_image(path_or_image, autorot: true, **options)
        if path_or_image.is_a?(::Vips::Image)
          image = path_or_image
        else
          source_path = path_or_image
          options     = Utils.select_valid_loader_options(source_path, options)

          image = ::Vips::Image.new_from_file(source_path, **options)
        end

        image = image.autorot if autorot && !options.key?(:autorotate)
        image
      end

      def self.save_image(image, destination_path, quality: nil, **options)
        options = options.merge(Q: quality) if quality
        options = Utils.select_valid_saver_options(destination_path, options)

        image.write_to_file(destination_path, **options)
      end

      def resize_to_limit(width, height, **options)
        width, height = default_dimensions(width, height)
        thumbnail(width, height, size: :down, **options)
      end

      def resize_to_fit(width, height, **options)
        width, height = default_dimensions(width, height)
        thumbnail(width, height, **options)
      end

      def resize_to_fill(width, height, **options)
        thumbnail(width, height, crop: :centre, **options)
      end

      def resize_and_pad(width, height, gravity: "centre", extend: nil, background: nil, alpha: nil, **options)
        embed_options = { extend: extend, background: background }
        embed_options.reject! { |name, value| value.nil? }

        image = thumbnail(width, height, **options)
        image = image.add_alpha if alpha && !image.has_alpha?
        image.gravity(gravity, width, height, **embed_options)
      end

      def rotate(degrees, background: nil)
        if degrees % 90 == 0
          image.rot(:"d#{degrees % 360}")
        else
          options = { angle: degrees }
          options[:background] = background if background

          image.similarity(**options)
        end
      end

      def composite(other, mode, **options)
        other = [other] unless other.is_a?(Array)

        other = other.map do |object|
          if object.is_a?(String)
            ::Vips::Image.new_from_file(object)
          elsif object.respond_to?(:to_path)
            ::Vips::Image.new_from_file(object.to_path)
          elsif object.respond_to?(:path)
            ::Vips::Image.new_from_file(object.path)
          else
            object
          end
        end

        image.composite(other, mode, **options)
      end

      # make Vips::Image#set, #set_type, and #set_value chainable
      def set(*args)       image.tap { |img| img.set(*args) }       end
      def set_type(*args)  image.tap { |img| img.set_type(*args) }  end
      def set_value(*args) image.tap { |img| img.set_value(*args) } end

      private

      def thumbnail(width, height, sharpen: SHARPEN_MASK, **options)
        image = self.image
        image = image.thumbnail_image(width, height: height, **options)
        image = image.conv(sharpen) if sharpen
        image
      end

      def default_dimensions(width, height)
        raise Error, "either width or height must be specified" unless width || height

        [width || ::Vips::MAX_COORD, height || ::Vips::MAX_COORD]
      end

      module Utils
        module_function

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
end
