require "mini_magick"
require "image_processing"

module ImageProcessing
  module MiniMagick
    extend Chainable

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
      accumulator :magick, ::MiniMagick::Tool

      SHARPEN_PARAMETERS = { radius: 0, sigma: 1 }

      def self.load_image(path_or_magick, page: nil, geometry: nil, auto_orient: true, **options)
        if path_or_magick.is_a?(::MiniMagick::Tool)
          magick = path_or_magick
        else
          source_path = path_or_magick
          magick = ::MiniMagick::Tool::Convert.new

          Utils.apply_options(magick, options)

          input_path  = source_path
          input_path += "[#{page}]" if page
          input_path += "[#{geometry}]" if geometry

          magick << input_path
        end

        magick.auto_orient if auto_orient
        magick
      end

      def self.save_image(magick, destination_path, allow_splitting: false, **options)
        Utils.apply_options(magick, options)

        magick << destination_path
        magick.call

        Utils.disallow_split_layers!(destination_path) unless allow_splitting
      end

      def resize_to_limit(width, height, **options)
        thumbnail("#{width}x#{height}>", **options)
      end

      def resize_to_fit(width, height, **options)
        thumbnail("#{width}x#{height}", **options)
      end

      def resize_to_fill(width, height, gravity: "Center", **options)
        thumbnail("#{width}x#{height}^", **options)
        magick.gravity gravity
        magick.background color(:transparent)
        magick.extent "#{width}x#{height}"
      end

      def resize_and_pad(width, height, background: :transparent, gravity: "Center", **options)
        thumbnail("#{width}x#{height}", **options)
        magick.background color(background)
        magick.gravity gravity
        magick.extent "#{width}x#{height}"
      end

      def rotate(degrees, background: nil)
        magick.background color(background) if background
        magick.rotate(degrees)
      end

      def composite(overlay = :none, mask: nil, compose: nil, gravity: nil, geometry: nil, args: nil, &block)
        return magick.composite if overlay == :none

        overlay_path = convert_to_path(overlay, "overlay")
        mask_path    = convert_to_path(mask, "mask") if mask

        magick << overlay_path
        magick << mask_path if mask_path

        magick.compose(compose) if compose
        define(compose: { args: args }) if args

        magick.gravity(gravity) if gravity
        magick.geometry(geometry) if geometry

        yield magick if block_given?

        magick.composite
      end

      def define(options)
        return magick.define(options) if options.is_a?(String)
        Utils.apply_define(magick, options)
      end

      def limits(options)
        options.each { |type, value| magick.args.unshift("-limit", type.to_s, value.to_s) }
        magick
      end

      def append(*args)
        magick.merge! args
      end

      private

      def color(value)
        return "rgba(255,255,255,0.0)" if value.to_s == "transparent"
        return "rgb(#{value.join(",")})" if value.is_a?(Array) && value.count == 3
        return "rgba(#{value.join(",")})" if value.is_a?(Array) && value.count == 4
        return value if value.is_a?(String)

        raise ArgumentError, "unrecognized color format: #{value.inspect} (must be one of: string, 3-element RGB array, 4-element RGBA array)"
      end

      def thumbnail(geometry, sharpen: {})
        magick.resize(geometry)

        if sharpen
          sharpen = SHARPEN_PARAMETERS.merge(sharpen)
          magick.sharpen("#{sharpen[:radius]}x#{sharpen[:sigma]}")
        end

        magick
      end

      def convert_to_path(file, name)
        if file.is_a?(String)
          file
        elsif file.respond_to?(:to_path)
          file.to_path
        elsif file.respond_to?(:path)
          file.path
        else
          raise ArgumentError, "#{name} must be a String, Pathname, or respond to #path"
        end
      end

      module Utils
        module_function

        def disallow_split_layers!(destination_path)
          layers = Dir[destination_path.sub(/\.\w+$/, '-*\0')]

          if layers.any?
            layers.each { |path| File.delete(path) }
            raise Error, "Multi-layer image is being converted into a single-layer format. You should either process individual layers or set :allow_splitting to true. See https://github.com/janko-m/image_processing/wiki/Splitting-a-PDF-into-multiple-images for how to process each layer individually."
          end
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

        def apply_define(magick, options)
          options.each do |namespace, settings|
            namespace = namespace.to_s.gsub("_", "-")

            settings.each do |key, value|
              key = key.to_s.gsub("_", "-")

              magick.define "#{namespace}:#{key}=#{value}"
            end
          end

          magick
        end
      end
    end
  end
end
