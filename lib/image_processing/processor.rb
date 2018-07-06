module ImageProcessing
  class Processor
    def initialize(pipeline)
      @pipeline = pipeline
    end

    def apply_operation(name, image, *args, &block)
      if respond_to?(name)
        public_send(name, image, *args, &block)
      else
        image.send(name, *args, &block)
      end
    end

    def custom(image, block)
      (block && block.call(image)) || image
    end

    private

    attr_reader :pipeline
  end
end
