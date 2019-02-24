module ImageProcessing
  # Abstract class inherited by individual processors.
  class Processor
    def self.call(source:, loader:, operations:, saver:, destination: nil)
      unless source.is_a?(String) || source.is_a?(self::ACCUMULATOR_CLASS)
        fail Error, "invalid source: #{source.inspect}"
      end

      accumulator = load_image(source, **loader)

      operations.each do |name, args, block|
        accumulator = apply_operation(accumulator, name, *args, &block)
      end

      if destination
        save_image(accumulator, destination, **saver)
      else
        accumulator
      end
    end

    # Use for processor subclasses to specify the name and the class of their
    # accumulator object (e.g. MiniMagick::Tool or Vips::Image).
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
      if method_defined?(name)
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
