module ImageProcessing
  # Abstract class inherited by individual processors.
  class Processor
    # Use for processor subclasses to specify the name and the class of their
    # accumulator object (e.g. MiniMagic::Tool or Vips::Image).
    def self.accumulator(name, klass)
      define_method(name) { @accumulator }
      protected(name)
      const_set(:ACCUMULATOR_CLASS, klass)
    end

    # Calls the operation to perform the processing. If the operation is
    # defined on the processor (macro), calls it. Otherwise calls the
    # operation directly on the accumulator object. This provides a common
    # umbrella above defined macros and direct operations.
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

    # Calls the given block with the accumulator object. Useful for when you
    # want to access the accumulator object directly.
    def custom(&block)
      (block && block.call(@accumulator)) || @accumulator
    end
  end
end
