module ImageProcessing
  class Processor
    def initialize(pipeline)
      @pipeline = pipeline
    end

    def apply_operation(name, image, *args)
      if respond_to?(name)
        public_send(name, image, *args)
      else
        image.send(name, *args)
      end
    end

    def custom(image, block)
      block.call(image) || image
    end

    private

    attr_reader :pipeline
  end
end
