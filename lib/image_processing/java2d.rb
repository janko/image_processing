# frozen_string_literal: true

require 'image_processing'

raise LoadError, 'ImageProcessing::Java2D requires JRuby.' unless RUBY_ENGINE == 'jruby'

require 'java'
java.lang.System.set_property('java.awt.headless', 'true') unless java.lang.System.get_property('java.awt.headless')

module ImageProcessing
  # Image processing backed only by ImageIO and Java2D from the JDK.
  module Java2D
    extend Chainable

    java_import java.awt.AlphaComposite
    java_import java.awt.Color
    java_import java.awt.RenderingHints
    java_import java.awt.image.BufferedImage
    java_import javax.imageio.IIOImage
    java_import javax.imageio.ImageIO
    java_import javax.imageio.ImageWriteParam

    JavaFile = java.io.File

    def self.valid_image?(file)
      Utils.read_image(file.path)
      true
    rescue StandardError
      false
    end

    # Executes ImageProcessing operations with a BufferedImage accumulator.
    class Processor < ImageProcessing::Processor
      accumulator :image, BufferedImage

      def self.load_image(path_or_image, auto_orient: true)
        return path_or_image if path_or_image.is_a?(BufferedImage)

        image = Utils.read_image(path_or_image.to_s)
        auto_orient ? Utils.orient(image, Utils.exif_orientation(path_or_image.to_s)) : image
      end

      def self.save_image(image, path, saver: nil, quality: nil, background: 'white')
        format = (saver || ::File.extname(path).delete_prefix('.')).to_s.downcase
        format = 'jpeg' if %w[jpg jpe].include?(format)
        image = Utils.flatten(image, Utils.color(background)) if format == 'jpeg' && image.color_model.has_alpha

        writers = ImageIO.get_image_writers_by_format_name(format)
        raise Error, "unsupported output format: #{format}" unless writers.has_next

        output = ImageIO.create_image_output_stream(JavaFile.new(path))
        writer = writers.next
        writer.set_output(output)
        params = writer.default_write_param
        if quality && params.can_write_compressed
          params.set_compression_mode(ImageWriteParam::MODE_EXPLICIT)
          params.set_compression_quality(quality.to_f / (quality.to_f > 1 ? 100 : 1))
        end
        writer.write(nil, IIOImage.new(image, nil, nil), params)
      ensure
        writer&.dispose
        output&.close
      end

      def resize_to_limit(width, height)
        resize(width, height, limit: true)
      end

      def resize_to_fit(width, height)
        resize(width, height)
      end

      def resize_to_fill(width, height, gravity: 'center')
        scaled = scale([width.to_f / image.width, height.to_f / image.height].max)
        crop_image(scaled, *position(scaled, width, height, gravity), width, height)
      end

      def resize_and_pad(width, height, background: :transparent, gravity: 'center')
        scaled = resize(width, height)
        canvas(scaled, width, height, background, gravity)
      end

      def resize_to_cover(width, height)
        scale([width.to_f / image.width, height.to_f / image.height].max)
      end

      def crop(*args)
        geometry = args.first.to_s.match(/\A(\d+)x(\d+)\+(-?\d+)\+(-?\d+)\z/) if args.one?

        if geometry
          width, height, left, top = geometry.captures.map(&:to_i)
        elsif args.length == 4
          left, top, width, height = args.map(&:to_i)
        else
          raise ArgumentError, 'wrong crop arguments (expected geometry or left, top, width, height)'
        end
        crop_image(image, left, top, width, height)
      end

      def rotate(degrees, background: :transparent)
        radians = degrees.to_f * Math::PI / 180
        sin = Math.sin(radians).abs
        cos = Math.cos(radians).abs
        sin = 0 if sin < 1e-12
        cos = 0 if cos < 1e-12
        width = (image.width * cos + image.height * sin).ceil
        height = (image.width * sin + image.height * cos).ceil
        result = BufferedImage.new(width, height, BufferedImage::TYPE_INT_ARGB)
        Utils.graphics(result) do |graphics|
          graphics.set_color(Utils.color(background))
          graphics.fill_rect(0, 0, width, height)
          graphics.translate(width / 2.0, height / 2.0)
          graphics.rotate(radians)
          graphics.draw_image(image, -image.width / 2.0, -image.height / 2.0, nil)
        end
        result
      end

      def flip(direction = :horizontal)
        result = blank(image.width, image.height)
        Utils.graphics(result) do |graphics|
          if direction.to_s == 'vertical'
            graphics.draw_image(image, 0, image.height, image.width, -image.height, nil)
          else
            graphics.draw_image(image, image.width, 0, -image.width, image.height, nil)
          end
        end
        result
      end

      def composite(overlay, mode: 'over', gravity: 'north-west', offset: nil)
        overlay = convert_to_image(overlay)
        left, top = position(image, overlay.width, overlay.height, gravity)
        left += offset[0] if offset
        top += offset[1] if offset
        result = blank(image.width, image.height)
        Utils.graphics(result) do |graphics|
          graphics.draw_image(image, 0, 0, nil)
          rule = Utils.composite_mode(mode)
          raise ArgumentError, "unsupported composite mode: #{mode}" unless rule

          graphics.set_composite(AlphaComposite.get_instance(rule))
          graphics.draw_image(overlay, left, top, nil)
        end
        result
      end

      # ImageIO does not carry source metadata into the new BufferedImage.
      def strip
        image
      end

      private

      def resize(width, height, limit: false)
        raise Error, 'either width or height must be specified' unless width || height

        factors = []
        factors << width.to_f / image.width if width
        factors << height.to_f / image.height if height
        factor = factors.min
        factor = 1 if limit && factor > 1
        scale(factor)
      end

      def scale(factor)
        width = [(image.width * factor).round, 1].max
        height = [(image.height * factor).round, 1].max
        return image if width == image.width && height == image.height

        result = blank(width, height)
        Utils.graphics(result, quality: true) do |graphics|
          graphics.draw_image(image, 0, 0, width, height, nil)
        end
        result
      end

      def crop_image(source, left, top, width, height)
        outside = left.negative? || top.negative? || left + width > source.width || top + height > source.height
        raise ArgumentError, 'crop is outside image bounds' if outside

        result = blank(width, height)
        Utils.graphics(result) do |graphics|
          graphics.draw_image(source, 0, 0, width, height, left, top, left + width, top + height, nil)
        end
        result
      end

      def canvas(source, width, height, background, gravity)
        result = blank(width, height)
        left, top = position(result, source.width, source.height, gravity)
        Utils.graphics(result) do |graphics|
          graphics.set_color(Utils.color(background))
          graphics.fill_rect(0, 0, width, height)
          graphics.draw_image(source, left, top, nil)
        end
        result
      end

      def position(container, width, height, gravity)
        gravity = gravity.to_s.downcase.tr('_', '-')
        x = gravity.include?('west') || gravity.include?('left') ? 0 : container.width - width
        y = gravity.include?('north') || gravity.include?('top') ? 0 : container.height - height
        x /= 2 unless gravity.match?(/west|east|left|right/)
        y /= 2 unless gravity.match?(/north|south|top|bottom/)
        [x, y]
      end

      def blank(width, height)
        BufferedImage.new(width, height, BufferedImage::TYPE_INT_ARGB)
      end

      def convert_to_image(object)
        return object if object.is_a?(BufferedImage)

        path = ::File.path(object)
        Processor.load_image(path, auto_orient: false)
      rescue TypeError
        raise ArgumentError, 'overlay must be a BufferedImage or path-like object'
      end
    end

    # Internal Java2D and ImageIO helpers shared by the processor entry points.
    module Utils
      COMPOSITE_MODES = {
        'clear' => AlphaComposite::CLEAR,
        'dest-over' => AlphaComposite::DST_OVER,
        'over' => AlphaComposite::SRC_OVER,
        'src' => AlphaComposite::SRC
      }.freeze

      COLORS = {
        'black' => Color::BLACK,
        'blue' => Color::BLUE,
        'cyan' => Color::CYAN,
        'gray' => Color::GRAY,
        'green' => Color::GREEN,
        'grey' => Color::GRAY,
        'magenta' => Color::MAGENTA,
        'red' => Color::RED,
        'white' => Color::WHITE,
        'yellow' => Color::YELLOW
      }.freeze

      module_function

      def composite_mode(mode)
        COMPOSITE_MODES[mode.to_s]
      end

      def read_image(path)
        image = begin
          ::File.open(path, 'rb') { |file| ImageIO.read(file.to_inputstream) }
        rescue StandardError
          raise Error, "unsupported or invalid image: #{path}"
        end

        # ImageIO returns null when no registered ImageReader accepts the stream.
        raise Error, "unsupported or invalid image: #{path}" unless image

        image
      end

      def color(value)
        name = value.to_s.downcase

        if name == 'transparent'
          Color.new(0, 0, 0, 0)
        elsif value.is_a?(Array) && (3..4).cover?(value.length)
          alpha = value[3] || 255
          alpha = (alpha * 255).round if alpha.to_f <= 1
          Color.new(*value.first(3).map(&:to_i), alpha.to_i)
        elsif COLORS.key?(name)
          COLORS.fetch(name)
        elsif value.is_a?(String) && value.match?(/\A(?:#|0x)[0-9a-f]{6}\z/i)
          Color.decode(value)
        else
          raise ArgumentError, "unrecognized color format: #{value.inspect}"
        end
      end

      def graphics(image, quality: false)
        graphics = image.create_graphics
        if quality
          graphics.set_rendering_hint(
            RenderingHints::KEY_INTERPOLATION,
            RenderingHints::VALUE_INTERPOLATION_BICUBIC
          )
          graphics.set_rendering_hint(RenderingHints::KEY_RENDERING, RenderingHints::VALUE_RENDER_QUALITY)
        end
        yield graphics
      ensure
        graphics&.dispose
      end

      def flatten(image, color)
        result = BufferedImage.new(image.width, image.height, BufferedImage::TYPE_INT_RGB)
        Utils.graphics(result) do |graphics|
          graphics.set_color(color)
          graphics.fill_rect(0, 0, image.width, image.height)
          graphics.draw_image(image, 0, 0, nil)
        end
        result
      end

      def exif_orientation(path)
        data = ::File.binread(path, 131_072)
        start = data.index("Exif\0\0")

        if start
          tiff = start + 6
          order = data.byteslice(tiff, 2)

          if %w[II MM].include?(order)
            short_format, long_format = order == 'II' ? %w[v V] : %w[n N]
            offset = data.byteslice(tiff + 4, 4).unpack1(long_format)
            count = data.byteslice(tiff + offset, 2).unpack1(short_format)
            count.times do |index|
              entry = data.byteslice(tiff + offset + 2 + index * 12, 12)
              return entry.byteslice(8, 2).unpack1(short_format) if entry.unpack1(short_format) == 0x0112
            end
          end
        end
        1
      rescue StandardError
        1
      end

      def orient(image, orientation)
        case orientation
        when 2
          Utils.transform(image) do |graphics|
            graphics.translate(image.width, 0)
            graphics.scale(-1, 1)
          end
        when 3
          Utils.transform(image) do |graphics|
            graphics.translate(image.width, image.height)
            graphics.rotate(Math::PI)
          end
        when 4
          Utils.transform(image) do |graphics|
            graphics.translate(0, image.height)
            graphics.scale(1, -1)
          end
        when 5
          Utils.transform(image, swap: true) do |graphics|
            graphics.transform(java.awt.geom.AffineTransform.new(0, 1, 1, 0, 0, 0))
          end
        when 6
          Utils.transform(image, swap: true) do |graphics|
            graphics.translate(image.height, 0)
            graphics.rotate(Math::PI / 2)
          end
        when 7
          Utils.transform(image, swap: true) do |graphics|
            graphics.transform(java.awt.geom.AffineTransform.new(0, -1, -1, 0, image.height, image.width))
          end
        when 8
          Utils.transform(image, swap: true) do |graphics|
            graphics.translate(0, image.width)
            graphics.rotate(-Math::PI / 2)
          end
        else
          image
        end
      end

      def transform(image, swap: false)
        width, height = swap ? [image.height, image.width] : [image.width, image.height]
        result = BufferedImage.new(width, height, BufferedImage::TYPE_INT_ARGB)
        Utils.graphics(result) do |graphics|
          yield graphics
          graphics.draw_image(image, 0, 0, nil)
        end
        result
      end
    end

    private_constant :Utils
  end

  # ActiveSupport camelizes :java2d as Java2d.
  Java2d = Java2D
end
