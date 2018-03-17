require "tempfile"

module ImageProcessing
  class Pipeline
    include Chainable

    def initialize(options)
      @default_options = options
    end

    def call!(save: true)
      fail Error, "source file is not provided" unless default_options[:source]

      processor = default_options[:processor].new
      image     = processor.load_image(default_options[:source], default_options[:loader])

      default_options[:operations].each do |name, args|
        if name == :custom
          image = args.first.call(image)
        else
          image = processor.apply_operation(name, image, *args)
        end
      end

      return image unless save

      source_path = default_options[:source].path if default_options[:source].respond_to?(:path)
      format      = default_options[:format] || File.extname(source_path.to_s)[1..-1] || "jpg"

      result = Tempfile.new(["image_processing", ".#{format}"], binmode: true)

      begin
        processor.save_image(image, result, default_options[:saver])
      rescue
        result.close!
        raise
      end

      result.open
      result
    end
  end
end
