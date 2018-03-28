module ImageProcessing
  class Builder
    include Chainable

    def initialize(options)
      @default_options = options
    end

    def call!(**options)
      Pipeline.new(default_options).call(**options)
    end
  end
end
