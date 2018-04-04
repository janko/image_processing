require "mini_magick"
require "image_processing"

module ImageProcessing
  module MiniMagick
    def self.valid_image?(file)
      ::MiniMagick::Tool::Convert.new do |convert|
        convert << file.path
        convert << "null:"
      end
      true
    rescue ::MiniMagick::Error
      false
    end

    class Processor < ImageProcessing::Processor
      IMAGE_CLASS        = ::MiniMagick::Tool
      SHARPEN_PARAMETERS = { radius: 0, sigma: 1 }

      def resize_to_limit(magick, width, height, **options)
        thumbnail(magick, "#{width}x#{height}>", **options)
      end

      def resize_to_fit(magick, width, height, **options)
        thumbnail(magick, "#{width}x#{height}", **options)
      end

      def resize_to_fill(magick, width, height, gravity: "Center", **options)
        thumbnail(magick, "#{width}x#{height}^", **options)
        magick.gravity gravity
        magick.background "rgba(255,255,255,0.0)" # transparent
        magick.extent "#{width}x#{height}"
      end

      def resize_and_pad(magick, width, height, background: :transparent, gravity: "Center", **options)
        background = "rgba(255,255,255,0.0)" if background.to_s == "transparent"

        thumbnail(magick, "#{width}x#{height}", **options)
        magick.background background
        magick.gravity gravity
        magick.extent "#{width}x#{height}"
      end

      def limits(magick, options)
        limit_args = options.flat_map { |type, value| %W[-limit #{type} #{value}] }
        prepend_args(magick, limit_args)
      end

      def append(magick, *args)
        magick.merge! args
      end

      def load_image(path_or_magick, page: nil, geometry: nil, auto_orient: true, **options)
        if path_or_magick.is_a?(::MiniMagick::Tool)
          magick = path_or_magick
        else
          source_path = path_or_magick
          magick = ::MiniMagick::Tool::Convert.new

          apply_options(magick, options)

          input_path  = source_path
          input_path += "[#{page}]" if page
          input_path += "[#{geometry}]" if geometry

          magick << input_path
        end

        magick.auto_orient if auto_orient
        magick
      end

      def save_image(magick, destination_path, **options)
        apply_options(magick, options)

        magick << destination_path

        magick.call
      end

      private

      def thumbnail(magick, geometry, sharpen: {})
        magick.resize(geometry)
        magick.sharpen(sharpen_value(sharpen)) if sharpen
        magick
      end

      def sharpen_value(parameters)
        parameters    = SHARPEN_PARAMETERS.merge(parameters)
        radius, sigma = parameters.values_at(:radius, :sigma)

        "#{radius}x#{sigma}"
      end

      def apply_options(magick, define: {}, **options)
        options.each do |option, value|
          case value
          when true, nil then magick.send(option)
          when false     then magick.send(option).+
          else                magick.send(option, *value)
          end
        end

        apply_define(magick, define)
      end

      def apply_define(magick, define)
        define.each do |namespace, options|
          namespace = namespace.to_s.gsub("_", "-")

          options.each do |key, value|
            key = key.to_s.gsub("_", "-")

            magick.define "#{namespace}:#{key}=#{value}"
          end
        end
      end

      def prepend_args(magick, args)
        magick.args.replace args + magick.args
        magick
      end
    end

    extend Chainable
  end
end
