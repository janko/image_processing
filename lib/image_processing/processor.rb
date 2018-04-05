module ImageProcessing
  class Processor
    def initialize(pipeline)
      @pipeline = pipeline
    end

    def apply(image, operations)
      operations.inject(image) do |result, (name, args)|
        if args == true || args.nil?
          apply_operation(name, result)
        else
          apply_operation(name, result, *args)
        end
      end
    end

    def apply_operation(name, image, *args)
      if respond_to?(name)
        public_send(name, image, *args)
      else
        image.send(name, *args)
      end
    end

    def custom(image, block)
      (block && block.call(image)) || image
    end

    private

    attr_reader :pipeline
  end
end
