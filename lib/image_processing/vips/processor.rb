gem "ruby-vips", "~> 2.0"
require "vips"
fail "image_processing/vips requires libvips 8.6+" unless Vips.at_least_libvips?(8, 6)

require "image_processing/vips/color"
require "tempfile"

module ImageProcessing
  module Vips
    class Processor
      DEFAULT_FORMAT = "jpg"

      def initialize(source)
        fail Error, "source file not provided" unless source
        fail Error, "source file doesn't respond to #path" unless source.respond_to?(:path) || source.is_a?(::Vips::Image)

        @source = source
      end

      def load_image(**options)
        return @source if @source.is_a?(::Vips::Image)

        ::Vips::Image.new_from_file(@source.path, fail: true, **options)
      end

      def apply_operation(name, image, *args)
        if respond_to?(name)
          public_send(name, image, *args)
        else
          image.send(name, *args)
        end
      end

      def resize_to_limit(image, width, height, **options)
        width, height = infer_dimensions([width, height], image.size)
        image.thumbnail_image(width, height: height, size: :down, **options)
      end

      def resize_to_fit(image, width, height, **options)
        width, height = infer_dimensions([width, height], image.size)
        image.thumbnail_image(width, height: height, **options)
      end

      def resize_to_fill(image, width, height, **options)
        image.thumbnail_image(width, height: height, crop: :centre, **options)
      end

      def resize_and_pad(image, width, height, background: "opaque", gravity: "centre", **options)
        image.thumbnail_image(width, height: height, **options)
          .gravity(gravity, width, height, extend: :background, background: Color.get(background))
      end

      def save_image(image, format = nil, **options)
        format ||= desired_format
        result   = Tempfile.new(["image_processing-vips", ".#{format}"], binmode: true)

        image.write_to_file(result.path, **options)
        result.open # refresh content

        result
      end

      private

      def infer_dimensions((width, height), (current_width, current_height))
        raise Error, "either width or height must be specified" unless width || height

        case
        when width.nil?
          ratio  = Rational(height, current_height)
          width  = (current_width * ratio).ceil
        when height.nil?
          ratio  = Rational(width, current_width)
          height = (current_height * ratio).ceil
        end

        [width, height]
      end

      def desired_format
        File.extname(original_path.to_s)[1..-1] || DEFAULT_FORMAT
      end

      def original_path
        @source.path if @source.respond_to?(:path)
      end
    end
  end
end
