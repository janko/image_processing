require "test_helper"
require "image_processing/vips"
require "mini_magick"

describe "ImageProcessing::Vips" do
  before do
    @portrait  = fixture_image("portrait.jpg")
    @landscape = fixture_image("landscape.jpg")
  end

  describe "Processor" do
    it "returns a tempfile in binary mode" do
      tempfile = ImageProcessing::Vips.convert("png").call(@portrait)
      assert_instance_of Tempfile, tempfile
      assert tempfile.binmode?
    end

    it "returns a Vips::Image if :save is set to false" do
      vips_image = ImageProcessing::Vips
        .resize_to_limit(400, 400)
        .call(@portrait, save: false)

      assert_instance_of Vips::Image, vips_image
      assert_equal [300, 400], vips_image.size

      vips_image = ImageProcessing::Vips
        .source(@portrait)
        .resize_to_limit(400, 400)
        .call(save: false)

      assert_instance_of Vips::Image, vips_image
      assert_equal [300, 400], vips_image.size
    end

    it "converts to specified format" do
      result = ImageProcessing::Vips.convert("png").call(@portrait)
      assert_equal ".png", File.extname(result.path)
      assert_type "PNG", result
    end

    it "retains original format if format was not specified" do
      jpg = ImageProcessing::Vips.convert("jpg").call(@portrait)
      png = ImageProcessing::Vips.convert("png").call(@portrait)
      result_jpg = ImageProcessing::Vips.invert.call(jpg)
      result_png = ImageProcessing::Vips.invert.call(png)
      assert_equal ".jpg", File.extname(result_jpg.path)
      assert_equal ".png", File.extname(result_png.path)
    end

    it "saves as JPEG when format is unknown" do
      png = ImageProcessing::Vips.convert("png").call(@portrait)
      result = ImageProcessing::Vips.invert.call(copy_to_tempfile(png))
      assert_equal ".jpg", File.extname(result.path)
      assert_type "JPEG", result
    end

    it "accepts Vips::Image as source" do
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

    it "allows setting metadata" do
      result = ImageProcessing::Vips
        .copy
        .set("icc-profile-data", "foobar")
        .call(@portrait)

      vips_image = Vips::Image.new_from_file(result.path)
      assert_equal "foobar", vips_image.get("icc-profile-data")
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

    it "raises exception when neither dimension is specified" do
      assert_raises(ImageProcessing::Vips::Error) do
        @pipeline.resize_to_limit!(nil, nil)
      end
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

    it "raises exception when neither dimension is specified" do
      assert_raises(ImageProcessing::Vips::Error) do
        @pipeline.resize_to_limit!(nil, nil)
      end
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

      it "accepts actual rgb values" do
        color = ImageProcessing::Vips::Color.get [0, 0, 0]
        assert_equal [0, 0, 0], color
      end

      it "raise an error if color is not found" do
        assert_raises ImageProcessing::Vips::Error do
          ImageProcessing::Vips::Color.get("unknown")
        end
      end
    end
  end
end
