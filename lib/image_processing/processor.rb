module ImageProcessing
  class Processor
    def self.accumulator(name, klass)
      define_method(name) { @accumulator }
      protected(name)
      const_set(:ACCUMULATOR_CLASS, klass)
    end

    def self.apply_operation(accumulator, name, *args, &block)
      if (instance_methods - Object.instance_methods).include?(name)
        instance = new(accumulator)
        instance.public_send(name, *args, &block)
      else
        accumulator.send(name, *args, &block)
      end
    end

    def initialize(accumulator = nil)
      @accumulator = accumulator
    end

    def custom(&block)
      (block && block.call(@accumulator)) || @accumulator
    end
  end
end
