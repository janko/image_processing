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
        image = thumbnail(width, height, **options)
        image = image.add_alpha if alpha && !image.has_alpha?
        image.gravity(gravity, width, height, extend: extend, background: background)
      end

      def rotate(degrees, background: nil)
        if degrees % 90 == 0
          image.rot(:"d#{degrees % 360}")
        else
          image.similarity(angle: degrees, background: background)
        end
      end

      def composite(overlay, _mode = nil, mode: "over", gravity: "north-west", offset: nil, **options)
        if _mode
          overlay = [overlay] unless overlay.is_a?(Array)
          overlay = overlay.map { |object| convert_to_image(object, "overlay") }

          return image.composite(overlay, _mode, **options)
        end

        overlay = convert_to_image(overlay, "overlay")
        overlay = overlay.add_alpha unless overlay.has_alpha? # so that #gravity can use transparent background

        if offset
          opposite_gravity = gravity.to_s.gsub(/\w+/, "north"=>"south", "south"=>"north", "east"=>"west", "west"=>"east")
          overlay = overlay.gravity(opposite_gravity, overlay.width + offset.first, overlay.height + offset.last)
        end

        overlay = overlay.gravity(gravity, image.width, image.height)

        image.composite(overlay, mode, **options)
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

      def convert_to_image(object, name)
        return object if object.is_a?(::Vips::Image)

        if object.is_a?(String)
          path = object
        elsif object.respond_to?(:to_path)
          path = object.to_path
        elsif object.respond_to?(:path)
          path = object.path
        else
          raise ArgumentError, "#{name} must be a Vips::Image, String, Pathname, or respond to #path"
        end

        ::Vips::Image.new_from_file(path)
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
