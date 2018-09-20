module ImageProcessing
  # Implements a chainable interface for building processing options.
  module Chainable
    # Specify the source image file.
    def source(file)
      branch source: file
    end

    # Specify the output format.
    def convert(format)
      branch format: format
    end

    # Specify processor options applied when loading the image.
    def loader(**options)
      branch loader: options
    end

    # Specify processor options applied when saving the image.
    def saver(**options)
      branch saver: options
    end

    # Add multiple operations as a hash or an array.
    #
    #   .apply(resize_to_limit: [400, 400], strip: true)
    #   # or
    #   .apply([[:resize_to_limit, [400, 400]], [:strip, true])
    def apply(operations)
      operations.inject(self) do |builder, (name, argument)|
        if argument == true || argument == nil
          builder.send(name)
        elsif argument.is_a?(Array)
          builder.send(name, *argument)
        else
          builder.send(name, argument)
        end
      end
    end

    # Assume that any unknown method names an operation supported by the
    # processor. Add a bang ("!") if you want processing to be performed.
    def method_missing(name, *args, &block)
      return super if name.to_s.end_with?("?")
      return send(name.to_s.chomp("!"), *args, &block).call if name.to_s.end_with?("!")

      operation(name, *args, &block)
    end

    # Add an operation defined by the processor.
    def operation(name, *args, &block)
      branch operations: [[name, args, *block]]
    end

    # Call the defined processing and get the result. Allows specifying
    # the source file and destination.
    def call(file = nil, destination: nil, **call_options)
      options = {}
      options = options.merge(source: file) if file
      options = options.merge(destination: destination) if destination

      branch(options).call!(**call_options)
    end

    # Creates a new builder object, merging current options with new options.
    def branch(loader: nil, saver: nil, operations: nil, **other_options)
      options = respond_to?(:options) ? self.options : DEFAULT_OPTIONS

      options = options.merge(loader: options[:loader].merge(loader)) if loader
      options = options.merge(saver: options[:saver].merge(saver)) if saver
      options = options.merge(operations: options[:operations] + operations) if operations
      options = options.merge(processor: self::Processor) unless self.is_a?(Builder)
      options = options.merge(other_options)

      options.freeze

      Builder.new(options)
    end

    # Empty options which the builder starts with.
    DEFAULT_OPTIONS = {
      source:     nil,
      loader:     {},
      saver:      {},
      format:     nil,
      operations: [],
      processor:  nil,
    }.freeze
  end
end
