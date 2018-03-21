require "tempfile"

module ImageProcessing
  class Pipeline
    include Chainable

    def initialize(options)
      @default_options = options
    end

    def call!(save: true)
      fail Error, "source file is not provided" unless default_options[:source]

      image_class = default_options[:processor]::IMAGE_CLASS

      if default_options[:source].is_a?(image_class)
        source = default_options[:source]
      elsif default_options[:source].is_a?(String)
        source = default_options[:source]
      elsif default_options[:source].respond_to?(:path)
        source = default_options[:source].path
      elsif default_options[:source].respond_to?(:to_path)
        source = default_options[:source].to_path
      else
        fail Error, "source file needs to respond to #path, or be a String, a Pathname, or a #{image_class} object"
      end

      processor = default_options[:processor].new
      image     = processor.load_image(source, default_options[:loader])

      default_options[:operations].each do |name, args|
        if name == :custom
          image = args.first.call(image) || image
        else
          image = processor.apply_operation(name, image, *args)
        end
      end

      return image unless save

      source_path = source if source.is_a?(String)
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
