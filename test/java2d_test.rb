require "minitest/autorun"
require "pathname"
require "tempfile"
require "image_processing"

describe "ImageProcessing::Java2D" do
  if RUBY_ENGINE != "jruby"
    it "is only available on JRuby" do
      assert_raises(LoadError) { ImageProcessing::Java2D }
    end
  else
    require "image_processing/java2d"

    it "supports ActiveSupport's camelization of :java2d" do
      assert_same ImageProcessing::Java2D, ImageProcessing::Java2d
    end

    it "keeps processor utilities private" do
      refute_respond_to ImageProcessing::Java2D::Processor, :graphics
      assert_raises(NameError) { ImageProcessing::Java2D::Utils }
    end

    def fixture(name)
      ::File.expand_path("fixtures/#{name}", __dir__)
    end

    def dimensions(image)
      image = ImageProcessing::Java2D::Processor.load_image(image.path) if image.respond_to?(:path)
      [image.width, image.height]
    end

    it "validates images with ImageIO" do
      ::File.open(fixture("portrait.jpg")) { |file| assert ImageProcessing::Java2D.valid_image?(file) }
      ::File.open(fixture("invalid.jpg")) { |file| refute ImageProcessing::Java2D.valid_image?(file) }

      error = assert_raises(ImageProcessing::Error) do
        ImageProcessing::Java2D::Processor.load_image(fixture("invalid.jpg"))
      end
      assert_match(/unsupported or invalid image/, error.message)
    end

    it "does not propagate backend errors for invalid images" do
      Tempfile.create(["invalid", ".jpg"]) do |file|
        file.binmode
        file.write("\xff\xd8")
        file.flush

        assert_raises(Java::JavaxImageio::IIOException) do
          ImageProcessing::Java2D::ImageIO.read(ImageProcessing::Java2D::JavaFile.new(file.path))
        end
        refute ImageProcessing::Java2D.valid_image?(file)

        error = assert_raises(ImageProcessing::Error) do
          ImageProcessing::Java2D::Processor.load_image(file.path)
        end
        assert_kind_of Java::JavaxImageio::IIOException, error.cause
      end
    end

    it "auto-orients images by default" do
      assert_equal [600, 800], dimensions(ImageProcessing::Java2D.call(fixture("rotated.jpg"), save: false))
      result = ImageProcessing::Java2D.loader(auto_orient: false).call(fixture("rotated.jpg"), save: false)
      assert_equal [800, 600], dimensions(result)
    end

    it "implements the resize macros" do
      pipeline = ImageProcessing::Java2D.source(fixture("portrait.jpg"))
      assert_equal [300, 400], dimensions(pipeline.resize_to_limit(400, 400).call(save: false))
      assert_equal [750, 1000], dimensions(pipeline.resize_to_fit(1000, 1000).call(save: false))
      assert_equal [400, 400], dimensions(pipeline.resize_to_fill(400, 400).call(save: false))
      assert_equal [400, 400], dimensions(pipeline.resize_and_pad(400, 400).call(save: false))
      assert_equal [300, 400], dimensions(pipeline.resize_to_cover(300, 200).call(save: false))
    end

    it "applies chained operations in order" do
      result = ImageProcessing::Java2D
        .source(fixture("portrait.jpg"))
        .resize_to_fit(300, 300)
        .rotate(90)
        .crop(0, 0, 200, 200)
        .call(save: false)

      assert_equal [200, 200], dimensions(result)
    end

    it "rejects unpublished operation keywords" do
      pipeline = ImageProcessing::Java2D.source(fixture("portrait.jpg"))

      assert_raises(ArgumentError) do
        pipeline.resize_to_fit(300, 300, sharpen: true).call(save: false)
      end
    end

    it "crops, rotates, and flips" do
      pipeline = ImageProcessing::Java2D.source(fixture("portrait.jpg"))
      assert_equal [300, 300], dimensions(pipeline.crop(0, 0, 300, 300).call(save: false))
      assert_equal [800, 600], dimensions(pipeline.rotate(90).call(save: false))
      assert_equal [600, 800], dimensions(pipeline.flip.call(save: false))
    end

    it "composites and writes images" do
      result = ImageProcessing::Java2D
        .source(fixture("portrait.jpg"))
        .composite(fixture("landscape.jpg"), gravity: "center")
        .convert("png")
        .call

      assert_equal [600, 800], dimensions(result)
      assert_operator result.size, :>, 0
    end

    it "accepts Ruby path-like objects for overlays" do
      pipeline = ImageProcessing::Java2D.source(fixture("portrait.jpg"))

      assert_equal [600, 800], dimensions(pipeline.composite(Pathname(fixture("landscape.jpg"))).call(save: false))
      ::File.open(fixture("landscape.jpg")) do |overlay|
        assert_equal [600, 800], dimensions(pipeline.composite(overlay).call(save: false))
      end
    end

    it "accepts a BufferedImage source" do
      image = ImageProcessing::Java2D::Processor.load_image(fixture("portrait.jpg"))
      assert_same image, ImageProcessing::Java2D.call(image, save: false)
    end
  end
end
