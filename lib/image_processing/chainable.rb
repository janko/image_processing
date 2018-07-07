module ImageProcessing
  module Chainable
    def source(file)
      branch source: file
    end

    def convert(format)
      branch format: format
    end

    def loader(**options)
      branch loader: options
    end

    def saver(**options)
      branch saver: options
    end

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

    def method_missing(name, *args, &block)
      return super if name.to_s.end_with?("?")
      return send(name.to_s.chomp("!"), *args, &block).call if name.to_s.end_with?("!")

      operation(name, *args, &block)
    end

    def operation(name, *args, &block)
      branch operations: [[name, args, *block]]
    end

    def call(file = nil, destination: nil, **call_options)
      options = {}
      options = options.merge(source: file) if file
      options = options.merge(destination: destination) if destination

      branch(options).call!(**call_options)
    end

    def branch(loader: nil, saver: nil, operations: nil, **other_options)
      options = respond_to?(:options) ? self.options : DEFAULT_OPTIONS

      options = options.merge(loader: options[:loader].merge(loader)) if loader
      options = options.merge(saver: options[:saver].merge(saver)) if saver
      options = options.merge(operations: options[:operations] + operations) if operations
      options = options.merge(processor_class: self::Processor) unless self.is_a?(Builder)
      options = options.merge(other_options)

      options.freeze

      Builder.new(options)
    end

    DEFAULT_OPTIONS = {
      source:          nil,
      loader:          {},
      saver:           {},
      format:          nil,
      operations:      [],
      processor_class: nil,
    }.freeze
  end
end
