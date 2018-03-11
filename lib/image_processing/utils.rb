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
  end
end
