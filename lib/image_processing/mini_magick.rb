gem "mini_magick", "~> 4.0"
require "mini_magick"

require "image_processing"
require "image_processing/mini_magick/deprecated_api"

module ImageProcessing
  module MiniMagick
    def self.valid_image?(file)
      ::MiniMagick::Tool::Convert.new do |convert|
        convert.regard_warnings
        convert << file.path
        convert << "null:"
      end
      true
    rescue ::MiniMagick::Error
      false
    end

    class Processor
      IMAGE_CLASS = ::MiniMagick::Tool
      TRANSPARENT = "rgba(255,255,255,0.0)"

      def apply_operation(name, magick, *args)
        if respond_to?(name)
          public_send(name, magick, *args)
        else
          magick.send(name, *args)
        end
      end

      def resize_to_limit(magick, width, height)
        magick.resize "#{width}x#{height}>"
      end

      def resize_to_fit(magick, width, height)
        magick.resize "#{width}x#{height}"
      end

      def resize_to_fill(magick, width, height, gravity: "Center")
        magick.resize "#{width}x#{height}^"
        magick.gravity gravity
        magick.background TRANSPARENT
        magick.extent "#{width}x#{height}"
      end

      def resize_and_pad(magick, width, height, background: TRANSPARENT, gravity: "Center")
        background = TRANSPARENT if background == "transparent"

        magick.resize "#{width}x#{height}"
        magick.background background
        magick.gravity gravity
        magick.extent "#{width}x#{height}"
      end

      def append(magick, *args)
        magick.merge! args
      end

      def load_image(path_or_magick, page: nil, geometry: nil, fail: true, auto_orient: true, define: {}, **options)
        if path_or_magick.is_a?(::MiniMagick::Tool)
          magick = path_or_magick
        else
          source_path = path_or_magick
          magick = ::MiniMagick::Tool::Convert.new

          apply_define(magick, define)
          apply_options(magick, options)

          input_path  = source_path
          input_path += "[#{page}]" if page
          input_path += "[#{geometry}]" if geometry

          magick << input_path
        end

        magick.regard_warnings if fail
        magick.auto_orient if auto_orient

        magick
      end

      def save_image(magick, destination_path, define: {}, **options)
        apply_define(magick, define)
        apply_options(magick, options)

        magick << destination_path

        magick.call
      end

      private

      def apply_define(magick, define)
        define.each do |namespace, options|
          namespace = namespace.to_s.gsub("_", "-")

          options.each do |key, value|
            key = key.to_s.gsub("_", "-")

            magick.define "#{namespace}:#{key}=#{value}"
          end
        end
      end

      def apply_options(magick, options)
        options.each do |option, value|
          case value
          when true  then magick.send(option)
          when false then magick.send(option).+
          else            magick.send(option, *value)
          end
        end
      end
    end

    extend Chainable

    include DeprecatedApi
  end
end
