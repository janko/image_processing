require "tempfile"
require "fileutils"

module ImageProcessing
  module MiniMagick
    module DeprecatedApi
      def self.included(base)
        base.extend(self)
      end

      def self.deprecated_processing_method(name, &body)
        define_method(name) do |*args, &block|
          return ImageProcessing::MiniMagick.send(name, *args, &block) if self != ImageProcessing::MiniMagick
          return super(*args, &block) unless args.first.respond_to?(:read)

          warn "[IMAGE_PROCESSING DEPRECATION WARNING] This API is deprecated and will be removed in ImageProcessing 1.0. Please use the new chainable API."

          file = args.shift

          if file.respond_to?(:path)
            instance_exec(file, *args, block, &body)
          else
            Utils.copy_to_tempfile(file) do |tempfile|
              instance_exec(tempfile, *args, block, &body)
            end
          end
        end

        define_method("#{name}!") do |*args, &block|
          return ImageProcessing::MiniMagick.send(name, *args, &block) if self != ImageProcessing::MiniMagick
          return super(*args, &block) unless args.first.respond_to?(:read)

          processed = send(name, *args, &block)
          source    = args.first

          if name == :convert
            File.delete(source.path)
          else
            processed.close
            FileUtils.mv processed.path, source.path
            source.open if source.is_a?(Tempfile)
          end

          source
        end
      end

      deprecated_processing_method :resize_to_limit do |file, *args, block|
        source(file)
          .custom(&block)
          .resize_to_limit!(*args)
      end

      deprecated_processing_method :resize_to_fit do |file, *args, block|
        source(file)
          .custom(&block)
          .resize_to_fit!(*args)
      end

      deprecated_processing_method :resize_to_fill do |file, *args, block|
        source(file)
          .custom(&block)
          .resize_to_fill!(*args)
      end

      deprecated_processing_method :resize_and_pad do |file, *args, block|
        source(file)
          .custom(&block)
          .resize_and_pad!(*args)
      end

      deprecated_processing_method :convert do |file, format, page = nil, block|
        source(file, page: page)
          .custom(&block)
          .convert!(format)
      end

      deprecated_processing_method :auto_orient do |file, *args, block|
        source(file)
          .custom(&block)
          .auto_orient!(*args)
      end

      deprecated_processing_method :resample do |file, width, height, block|
        source(file)
          .custom(&block)
          .resample!("#{width}x#{height}")
      end

      deprecated_processing_method :crop do |file, width, height, x_offset, y_offset, block|
        source(file)
          .custom(&block)
          .crop!("#{width}x#{height}+#{x_offset}+#{y_offset}")
      end

      deprecated_processing_method :corrupted? do |file, block|
        valid_image?(file)
      end

      module Utils
        module_function

        def copy_to_tempfile(io)
          extension = File.extname(io.path) if io.respond_to?(:path)
          tempfile  = Tempfile.new(["image_processing", extension.to_s], binmode: true)

          IO.copy_stream(io, tempfile)

          io.rewind
          tempfile.open # refresh content

          yield tempfile
        ensure
          tempfile.close! if tempfile
        end
      end
    end
  end
end
