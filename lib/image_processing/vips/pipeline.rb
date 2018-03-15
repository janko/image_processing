module ImageProcessing
  module Vips
    class Pipeline
      include Chainable

      def initialize(options)
        @default_options = options
      end

      def call!
        processor = Processor.new(default_options[:source])
        image     = processor.load_image(default_options[:loader])

        default_options[:operations].each do |name, args|
          image = processor.apply_operation(name, image, *args)
        end

        processor.save_image(image, default_options[:format], default_options[:saver])
      end
    end
  end
end
