require "test_helper"
require "image_processing/vips"
require "mini_magick"

describe "ImageProcessing::Vips" do
  before do
    @portrait  = fixture_image("portrait.jpg")
    @landscape = fixture_image("landscape.jpg")
  end

  it "applies vips operations" do
    actual = ImageProcessing::Vips.invert.call(@portrait)
    expected = Tempfile.new(["result", ".jpg"], binmode: true).tap do |tempfile|
      image = Vips::Image.new_from_file(@portrait.path)
      image = image.invert
      image.write_to_file(tempfile.path)
    end

    assert_similar expected, actual
  end

  it "applies macro operations" do
    actual = ImageProcessing::Vips.resize_to_limit(400, 400).call(@portrait)
    expected = Tempfile.new(["result", ".jpg"], binmode: true).tap do |tempfile|
      image = Vips::Image.new_from_file(@portrait.path)
      image = image.thumbnail_image(400, height: 400, size: :down)
      image.write_to_file(tempfile.path)
    end

    assert_similar expected, actual
  end

  it "applies setting metadata" do
    image = ImageProcessing::Vips
      .copy
      .set("icc-profile-data", "foobar")
      .call(@portrait, save: false)

    assert_equal "foobar", image.get("icc-profile-data")
  end

  it "applies format" do
    result = ImageProcessing::Vips.convert("png").call(@portrait)
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

  it "accepts Vips::Image as source" do
    vips_image = Vips::Image.new_from_file(@portrait.path)
    result = ImageProcessing::Vips.convert("png").call(vips_image)
    assert_equal ".png", File.extname(result.path)
    assert_type "PNG", result
  end

  it "fails on invalid source" do
    assert_raises(ImageProcessing::Error) do
      ImageProcessing::Vips.call(StringIO.new)
    end

    assert_raises(ImageProcessing::Error) do
      ImageProcessing::Vips.source(StringIO.new).call
    end
  end

  it "fails for corrupted files" do
    corrupted = fixture_image("corrupted.jpg")
    pipeline = ImageProcessing::Vips.source(corrupted).shrink(2, 2)
    assert_raises(Vips::Error) { pipeline.call }
  end

  it "allows ignoring processing warnings" do
    corrupted = fixture_image("corrupted.jpg")
    pipeline = ImageProcessing::Vips.source(corrupted).shrink(2, 2)
    pipeline.loader(fail: false).call
  end

  describe ".valid_image?" do
    it "returns true for correct images" do
      assert ImageProcessing::Vips.valid_image?(@portrait)
      assert ImageProcessing::Vips.valid_image?(copy_to_tempfile(@portrait)) # no extension
    end

    it "returns false for corrupted images" do
      refute ImageProcessing::Vips.valid_image?(fixture_image("corrupted.jpg"))
      refute ImageProcessing::Vips.valid_image?(copy_to_tempfile(fixture_image("corrupted.jpg"))) # no extension
    end
  end

  describe "#resize_to_limit" do
    before do
      @pipeline = ImageProcessing::Vips.source(@portrait)
    end

    it "srinks image to fit the specified dimensions" do
      assert_dimensions [300, 400], @pipeline.resize_to_limit!(400, 400)
    end

    it "doesn't enlarge image if it's smaller than specified dimensions" do
      assert_dimensions [600, 800], @pipeline.resize_to_limit!(1000, 1000)
    end

    it "doesn't require both dimensions" do
      assert_dimensions [300, 400], @pipeline.resize_to_limit!(300, nil)
      assert_dimensions [600, 800], @pipeline.resize_to_limit!(800, nil)

      assert_dimensions [300, 400], @pipeline.resize_to_limit!(nil, 400)
      assert_dimensions [600, 800], @pipeline.resize_to_limit!(nil, 1000)
    end

    it "raises exception when neither dimension is specified" do
      assert_raises(ImageProcessing::Error) do
        @pipeline.resize_to_limit!(nil, nil)
      end
    end

    it "produces correct image" do
      expected = fixture_image("limit.jpg")
      assert_similar expected, @pipeline.resize_to_limit!(400, 400)
    end

    it "accepts thumbnail options" do
      assert_dimensions [400, 400], @pipeline.resize_to_limit!(400, 400, crop: :centre)
    end
  end

  describe "#resize_to_fit" do
    before do
      @pipeline = ImageProcessing::Vips.source(@portrait)
    end

    it "shrinks image to fit specified dimensions" do
      assert_dimensions [300, 400], @pipeline.resize_to_fit!(400, 400)
    end

    it "enlarges image if it's smaller than given dimensions" do
      assert_dimensions [750, 1000], @pipeline.resize_to_fit!(1000, 1000)
    end

    it "doesn't require both dimensions" do
      assert_dimensions [300, 400],  @pipeline.resize_to_fit!(300, nil)
      assert_dimensions [750, 1000], @pipeline.resize_to_fit!(750, nil)

      assert_dimensions [300, 400],  @pipeline.resize_to_fit!(nil, 400)
      assert_dimensions [750, 1000], @pipeline.resize_to_fit!(nil, 1000)
    end

    it "raises exception when neither dimension is specified" do
      assert_raises(ImageProcessing::Error) do
        @pipeline.resize_to_limit!(nil, nil)
      end
    end

    it "produces correct image" do
      expected = fixture_image("fit.jpg")
      assert_similar expected, @pipeline.resize_to_fit!(400, 400)
    end

    it "accepts thumbnail options" do
      assert_dimensions [400, 400], @pipeline.resize_to_fit!(400, 400, crop: :centre)
    end
  end

  describe "#resize_to_fill" do
    before do
      @pipeline = ImageProcessing::Vips.source(@portrait)
    end

    it "resizes and crops the image to fill out the given dimensions" do
      assert_dimensions [400, 400], @pipeline.resize_to_fill!(400, 400)
    end

    it "enlarges image and crops it if it's smaller than given dimensions" do
      assert_dimensions [1000, 1000], @pipeline.resize_to_fill!(1000, 1000)
    end

    it "produces correct image" do
      expected = fixture_image("fill.jpg")
      assert_similar expected, @pipeline.resize_to_fill!(400, 400)
    end

    it "accepts thumbnail options" do
      attention = @pipeline.resize_to_fill!(400, 400, crop: :attention)
      centre    = @pipeline.resize_to_fill!(400, 400, crop: :centre)
      refute_similar centre, attention
    end
  end

  describe "#resize_and_pad" do
    before do
      @pipeline = ImageProcessing::Vips.source(@portrait)
    end

    it "resizes and fills out the remaining space to fill out the given dimensions" do
      assert_dimensions [400, 400], @pipeline.resize_and_pad!(400, 400)
    end

    it "enlarges image and fills out the remaining space to fill out the given dimensions" do
      assert_dimensions [1000, 1000], @pipeline.resize_and_pad!(1000, 1000)
    end

    it "produces correct image" do
      expected = fixture_image("pad.jpg")
      assert_similar expected, @pipeline.resize_and_pad!(400, 400, background: "red")
    end

    it "produces correct image when enlarging" do
      @pipeline = ImageProcessing::Vips.source(@landscape)
      expected = fixture_image("pad-large.jpg")
      assert_similar expected, @pipeline.resize_and_pad!(1000, 1000, background: "green")
    end

    it "accepts gravity" do
      centre    = @pipeline.resize_and_pad!(400, 400)
      northwest = @pipeline.resize_and_pad!(400, 400, gravity: "north-west")
      refute_similar centre, northwest
    end

    it "accepts thumbnail options" do
      pad  = @pipeline.resize_and_pad!(400, 400)
      crop = @pipeline.resize_and_pad!(400, 400, crop: :centre)
      refute_similar pad, crop
    end
  end

  describe "Color" do
    it "returns rgb format of color" do
      assert_equal [255, 250, 250], ImageProcessing::Vips::Color.get("snow")
    end

    it "accepts both spellings of grey" do
      assert_equal [8, 8, 8],       ImageProcessing::Vips::Color.get("grey3")
      assert_equal [112, 128, 144], ImageProcessing::Vips::Color.get("slategray")
    end

    it "accepts any casing" do
      assert_equal [240, 128, 128], ImageProcessing::Vips::Color.get("LightCoral")
    end

    it "accepts actual rgb values" do
      assert_equal [0, 0, 0], ImageProcessing::Vips::Color.get([0, 0, 0])
    end

    it "raise an error if color is not found" do
      assert_raises ImageProcessing::Error do
        ImageProcessing::Vips::Color.get("unknown")
      end
    end
  end
end
