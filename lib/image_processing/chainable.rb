module ImageProcessing
  module Chainable
    def source(file)
      branch default_options.merge(source: file)
    end

    def convert(format)
      branch default_options.merge(format: format)
    end

    def loader(**options)
      loader = default_options[:loader].merge(options)
      branch default_options.merge(loader: loader)
    end

    def saver(**options)
      saver = default_options[:saver].merge(options)
      branch default_options.merge(saver: saver)
    end

    def operation(name, *args)
      operations = default_options[:operations] + [[name, args]]
      branch default_options.merge(operations: operations)
    end

    def custom(&block)
      block ? operation(:custom, block) : self
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

    def call(file = nil, destination: nil, **call_options)
      options = default_options
      options = options.merge(source: file) if file
      options = options.merge(destination: destination) if destination

      branch(options).call!(**call_options)
    end

    def branch(options)
      options = options.merge(processor_class: self::Processor) unless self.is_a?(Builder)

      Builder.new(options)
    end

    def default_options
      @default_options ||= {
        source:          nil,
        loader:          {},
        saver:           {},
        format:          nil,
        operations:      [],
        processor_class: nil,
      }
    end
  end
end
