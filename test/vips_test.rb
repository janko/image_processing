require "test_helper"
require "image_processing/vips"
require "mini_magick"

describe "ImageProcessing::Vips" do
  def assert_similar(expected, actual)
    return if RUBY_ENGINE == "jruby"

    a = Phashion::Image.new(expected.path)
    b = Phashion::Image.new(actual.path)

    distance = a.distance_from(b).abs

    assert_operator distance, :<=, 4
  end

  def assert_dimensions(dimensions, file)
    assert_equal dimensions, Vips::Image.new_from_file(file.path).size
  end

  def assert_type(type, file)
    assert_equal type, MiniMagick::Image.new(file.path).type
  end

  before do
    @portrait  = fixture_image("portrait.jpg")
    @landscape = fixture_image("landscape.jpg")
  end

  describe "Chainable" do
    it "accepts source" do
      pipeline = ImageProcessing::Vips.source(@portrait)
      assert_equal @portrait, pipeline.default_options[:source]
    end

    it "accepts format" do
      pipeline = ImageProcessing::Vips.convert("png")
      assert_equal "png", pipeline.default_options[:format]
    end

    it "accepts loader options" do
      pipeline = ImageProcessing::Vips.loader(shrink: 2)
      assert_equal Hash[shrink: 2], pipeline.default_options[:loader]

      pipeline = pipeline.loader(autorotate: true)
      assert_equal Hash[shrink: 2, autorotate: true], pipeline.default_options[:loader]
    end

    it "accepts saver options" do
      pipeline = ImageProcessing::Vips.saver(strip: true)
      assert_equal Hash[strip: true], pipeline.default_options[:saver]

      pipeline = pipeline.saver(Q: 100)
      assert_equal Hash[strip: true, Q: 100], pipeline.default_options[:saver]
    end

    it "accepts operations" do
      pipeline = ImageProcessing::Vips.shrink(2, 2)
      assert_equal [[:shrink, [2, 2]]], pipeline.default_options[:operations]

      pipeline = pipeline.invert
      assert_equal [[:shrink, [2, 2]], [:invert, []]], pipeline.default_options[:operations]
    end

    it "merges different options" do
      pipeline = ImageProcessing::Vips
        .resize_to_fill(400, 400)
        .convert("png")

      assert_equal [[:resize_to_fill, [400, 400]]], pipeline.default_options[:operations]
      assert_equal "png", pipeline.default_options[:format]
    end

    it "doesn't mutate the receiver" do
      pipeline_jpg = ImageProcessing::Vips.convert("jpg")
      pipeline_png = pipeline_jpg.convert("png")

      assert_equal "jpg", pipeline_jpg.default_options[:format]
      assert_equal "png", pipeline_png.default_options[:format]
    end

    it "executes processing on #call with source" do
      result = ImageProcessing::Vips.convert("png").call(@portrait)
      assert_instance_of Tempfile, result
      assert_type "PNG", result
    end

    it "executes processing on #call without source" do
      result = ImageProcessing::Vips.source(@portrait).convert("png").call
      assert_instance_of Tempfile, result
      assert_type "PNG", result
    end

    it "executes processing on bang operation method" do
      result = ImageProcessing::Vips.source(@portrait).convert!("png")
      assert_instance_of Tempfile, result
      assert_type "PNG", result

      result = ImageProcessing::Vips.source(@portrait).shrink!(2, 2)
      assert_instance_of Tempfile, result
      assert_dimensions [300, 400], result

      result = ImageProcessing::Vips.source(@portrait).resize_to_fill!(400, 400)
      assert_instance_of Tempfile, result
      assert_dimensions [400, 400], result
    end

    it "accepts a custom block" do
      actual   = ImageProcessing::Vips.custom(&:invert).call(@portrait)
      expected = ImageProcessing::Vips.invert.call(@portrait)
      assert_similar expected, actual
    end

    it "returns the tempfile in binary mode" do
      tempfile = ImageProcessing::Vips.convert("png").call(@portrait)
      assert tempfile.binmode?
    end
  end

  describe "Processor" do
    it "converts to specified format" do
      result = ImageProcessing::Vips.convert("png").call(@portrait)
      assert_equal ".png", File.extname(result.path)
      assert_type "PNG", result
    end

    it "maintains the original format" do
      png = ImageProcessing::Vips.convert("png").call(@portrait)
      result = ImageProcessing::Vips.call(png)
      assert_equal ".png", File.extname(result.path)
      assert_type "PNG", result
    end

    it "saves as JPEG when original format is unknown" do
      png = ImageProcessing::Vips.convert("png").call(@portrait)
      result = ImageProcessing::Vips.call(copy_to_tempfile(png))
      assert_equal ".jpg", File.extname(result.path)
      assert_type "JPEG", result
    end

    it "accepts a Vips::Image as source" do
      vips_image = Vips::Image.new_from_file(@portrait.path)
      result = ImageProcessing::Vips.convert("png").call(vips_image)
      assert_equal ".png", File.extname(result.path)
      assert_type "PNG", result
    end

    it "applies loader options" do
      result = ImageProcessing::Vips.loader(shrink: 2).call(@portrait)
      assert_dimensions [300, 400], result
    end

    it "applies saver options" do
      result = ImageProcessing::Vips.saver(strip: true).call(@portrait)
      result_image = Vips::Image.new_from_file(result.path)
      refute_includes result_image.get_fields, "exif-data"
    end

    it "applies a sequence of operations" do
      actual = ImageProcessing::Vips
        .invert
        .shrink(2, 2)
        .call(@portrait)

      expected = ImageProcessing::Vips.invert.call(@portrait)
      expected = ImageProcessing::Vips.shrink(2, 2).call(expected)

      assert_similar expected, actual
    end

    it "fails for corrupted files" do
      corrupted = fixture_image("corrupted.jpg")
      pipeline = ImageProcessing::Vips.source(corrupted).shrink(2, 2)
      assert_raises(Vips::Error) { pipeline.call }
    end

    it "allows overriding failing for corrupted files" do
      corrupted = fixture_image("corrupted.jpg")
      pipeline = ImageProcessing::Vips.source(corrupted).shrink(2, 2)
      pipeline.loader(fail: false).call
    end

    it "raises exception when source isn't valid" do
      assert_raises(ImageProcessing::Vips::Error) do
        ImageProcessing::Vips.source(StringIO.new).call
      end
    end

    it "raises exception when source was not provided" do
      assert_raises(ImageProcessing::Vips::Error) do
        ImageProcessing::Vips.call
      end
    end
  end

  describe "#resize_to_limit" do
    before do
      @pipeline = ImageProcessing::Vips.source(@portrait)
    end

    it "srinks image to fit the specified dimensions" do
      result = @pipeline.resize_to_limit!(400, 400)
      assert_dimensions [300, 400], result
    end

    it "doesn't enlarge image if it's smaller than specified dimensions" do
      result = @pipeline.resize_to_limit!(1000, 1000)
      assert_dimensions [600, 800], result
    end

    it "doesn't require both dimensions" do
      result = @pipeline.resize_to_limit!(300, nil)
      assert_dimensions [300, 400], result

      result = @pipeline.resize_to_limit!(nil, 1000)
      assert_dimensions [600, 800], result
    end

    it "produces correct image" do
      result = @pipeline.resize_to_limit!(400, 400)
      assert_similar fixture_image("limit.jpg"), result
    end

    it "accepts thumbnail options" do
      result = @pipeline.resize_to_limit!(400, 400, crop: :centre)
      assert_dimensions [400, 400], result
    end
  end

  describe "#resize_to_fit" do
    before do
      @pipeline = ImageProcessing::Vips.source(@portrait)
    end

    it "shrinks image to fit specified dimensions" do
      result = @pipeline.resize_to_fit!(400, 400)
      assert_dimensions [300, 400], result
    end

    it "enlarges image if it's smaller than given dimensions" do
      result = @pipeline.resize_to_fit!(1000, 1000)
      assert_dimensions [750, 1000], result
    end

    it "doesn't require both dimensions" do
      result = @pipeline.resize_to_fit!(300, nil)
      assert_dimensions [300, 400], result

      result = @pipeline.resize_to_fit!(nil, 1000)
      assert_dimensions [750, 1000], result
    end

    it "produces correct image" do
      result = @pipeline.resize_to_fit!(400, 400)
      assert_similar fixture_image("fit.jpg"), result
    end

    it "accepts thumbnail options" do
      result = @pipeline.resize_to_fit!(400, 400, crop: :centre)
      assert_dimensions [400, 400], result
    end
  end

  describe "#resize_to_fill" do
    before do
      @pipeline = ImageProcessing::Vips.source(@portrait)
    end

    it "resizes and crops the image to fill out the given dimensions" do
      result = @pipeline.resize_to_fill!(400, 400)
      assert_dimensions [400, 400], result
    end

    it "enlarges image and crops it if it's smaller than given dimensions" do
      result = @pipeline.resize_to_fill!(1000, 1000)
      assert_dimensions [1000, 1000], result
    end

    it "produces correct image" do
      result = @pipeline.resize_to_fill!(400, 400)
      assert_similar fixture_image("fill.jpg"), result
    end

    it "accepts thumbnail options" do
      attention = @pipeline.resize_to_fill!(400, 400, crop: :attention)
      centre    = @pipeline.resize_to_fill!(400, 400, crop: :centre)
      refute_equal centre.read, attention.read
    end
  end

  describe "#resize_and_pad" do
    before do
      @pipeline = ImageProcessing::Vips.source(@portrait)
    end

    it "resizes and fills out the remaining space to fill out the given dimensions" do
      result = @pipeline.resize_and_pad!(400, 400)
      assert_dimensions [400, 400], result
    end

    it "enlarges image and fills out the remaining space to fill out the given dimensions" do
      result = @pipeline.resize_and_pad!(1000, 1000, background: "red")
      assert_dimensions [1000, 1000], result
    end

    it "produces correct image" do
      result = @pipeline.resize_and_pad!(400, 400, background: "red")
      assert_similar fixture_image("pad.jpg"), result
    end

    it "produces correct image when enlarging" do
      @pipeline = ImageProcessing::Vips.source(@landscape)
      result = @pipeline.resize_and_pad!(1000, 1000, background: "green")
      assert_similar fixture_image("pad-large.jpg"), result
    end

    it "accepts thumbnail options" do
      crop = @pipeline.resize_and_pad!(400, 400, crop: :centre)
      pad = @pipeline.resize_and_pad!(400, 400)
      refute_equal pad.read, crop.read
    end
  end

  describe "Color" do
    describe "#get" do
      it "returns rgb format of color" do
        color = ImageProcessing::Vips::Color.get("snow")
        assert_equal [255, 250, 250], color
      end

      it "accepts both spellings of grey" do
        color = ImageProcessing::Vips::Color.get("grey3")
        assert_equal [8, 8, 8], color

        color = ImageProcessing::Vips::Color.get("slategray")
        assert_equal [112, 128, 144], color
      end

      it "accepts any casing" do
        color = ImageProcessing::Vips::Color.get("LightCoral")
        assert_equal [240, 128, 128], color
      end

      it "raise an error if color is not found" do
        assert_raises ImageProcessing::Vips::Error do
          ImageProcessing::Vips::Color.get("unknown")
        end
      end
    end
  end
end
