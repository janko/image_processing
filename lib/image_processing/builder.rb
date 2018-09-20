module ImageProcessing
  class Builder
    include Chainable

    attr_reader :options

    def initialize(options)
      @options = options
    end

    # Calls the pipeline to perform the processing from built options.
    def call!(**options)
      Pipeline.new(self.options).call(**options)
    end
  end
end
