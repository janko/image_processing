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

    def custom(&block)
      operation :custom, block
    end

    def method_missing(name, *args)
      if name.to_s.end_with?("!")
        send(name.to_s.chomp("!"), *args).call
      elsif name.to_s.end_with?("?")
        super
      else
        operation(name, *args)
      end
    end

    def operation(name, *args)
      branch operations: [[name, args]]
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
