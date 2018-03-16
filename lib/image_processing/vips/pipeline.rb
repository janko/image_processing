module ImageProcessing
  module Vips
    class Pipeline
      include Chainable

      def initialize(options)
        @default_options = options
      end

      def call!(save: true)
        processor = Processor.new(default_options[:source])
        image     = processor.load_image(default_options[:loader])

        default_options[:operations].each do |name, args|
          if name == :custom
            image = args.first.call(image)
          else
            image = processor.apply_operation(name, image, *args)
          end
        end

        if save
          processor.save_image(image, default_options[:format], default_options[:saver])
        else
          image
        end
      end
    end
  end
end
