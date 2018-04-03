module ImageProcessing
  class Builder
    include Chainable

    attr_reader :options

    def initialize(options)
      @options = options
    end

    def call!(**options)
      Pipeline.new(self.options).call(**options)
    end
  end
end
