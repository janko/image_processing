module ImageProcessing
  # Abstract class inherited by individual analyzers.
  class Analyzer
    def initialize(image)
      @image = image
    end

    def analyze
      { width: @image.width, height: @image.height, rotated: rotated? }
    end
  end
end
