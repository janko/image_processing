require "tempfile"

module ImageProcessing
  module Utils
    module_function

    def copy_to_tempfile(io)
      tempfile = Tempfile.new("image_processing", binmode: true)

      IO.copy_stream(io, tempfile)

      io.rewind
      tempfile.open # refresh content

      yield tempfile if block_given?
    ensure
      tempfile.close! if tempfile && block_given?
    end

    def infer_dimensions((width, height), (current_width, current_height))
      raise ArgumentError, "either width or height must be specified" unless width || height

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
  end
end
