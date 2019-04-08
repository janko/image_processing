require "test_helper"
require "image_processing/vips"
require "pathname"

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

  it "allows changing metadata" do
    image = ImageProcessing::Vips
      .copy
      .set("icc-profile-data", "foobar")
      .set_type(Vips::BLOB_TYPE, "foo", "bar")
      .remove("exif-data")
      .call(@portrait, save: false)

    assert_equal "foobar", image.get("icc-profile-data")
    assert_equal "bar",    image.get("foo")

    assert_raises(Vips::Error) { image.get("exif-data") }
  end

  it "applies format" do
    result = ImageProcessing::Vips.convert("png").call(@portrait)
    assert_equal ".png", File.extname(result.path)
    assert_type "PNG", result
  end

  it "auto rotates by default" do
    result = ImageProcessing::Vips.call(fixture_image("rotated.jpg"))
    assert_dimensions [600, 800], result

    result = ImageProcessing::Vips.call(Vips::Image.new_from_file(fixture_image("rotated.jpg").path))
    assert_dimensions [600, 800], result

    result = ImageProcessing::Vips.loader(autorot: false).call(fixture_image("rotated.jpg"))
    assert_dimensions [800, 600], result

    result = ImageProcessing::Vips.loader(autorotate: false).call(fixture_image("rotated.jpg"))
    assert_dimensions [800, 600], result
  end

  it "accepts Vips::Image as source" do
    vips_image = Vips::Image.new_from_file(fixture_image("rotated.jpg").path)
    result = ImageProcessing::Vips.source(vips_image).call
    assert_dimensions [600, 800], result
  end

  it "applies loader options" do
    result = ImageProcessing::Vips.loader(shrink: 2).call(@portrait)
    assert_dimensions [300, 400], result
  end

  it "ignores loader options that are not defined" do
    png = ImageProcessing::Vips.convert("png").call(@portrait)
    ImageProcessing::Vips.loader(shrink: 2).call(png)
  end

  it "raises correct Vips::Error on unknown loader" do
    error = assert_raises(Vips::Error) { ImageProcessing::Vips.convert("jpg").call(Tempfile.new("")) }
    assert_includes error.message, "not a known file format"
  end

  it "accepts :loader" do
    error = assert_raises(Vips::Error) do
      ImageProcessing::Vips.loader(loader: :webp).call(@portrait)
    end
    assert_match "webp2vips", error.message
  end

  it "applies saver options" do
    result = ImageProcessing::Vips.saver(strip: true).call(@portrait)
    refute_includes Vips::Image.new_from_file(result.path).get_fields, "exif-data"
  end

  it "converts :quality saver option to :Q" do
    result1 = ImageProcessing::Vips.saver(quality: 50).call(@portrait)
    result2 = ImageProcessing::Vips.saver(quality: 100).call(@portrait)
    assert result1.size < result2.size
  end

  it "ignores saver options that are not defined" do
    ImageProcessing::Vips.saver(Q: 85).convert("png").call(@portrait)
  end

  it "raises correct Vips::Error on unknown saver" do
    error = assert_raises(Vips::Error) { ImageProcessing::Vips.convert("foo").call(@portrait) }
    assert_includes error.message, "No known saver"
  end

  it "accepts :saver" do
    result = ImageProcessing::Vips.saver(saver: :webp).call(@portrait)
    assert_type "WEBP", result
  end

  describe ".valid_image?" do
    it "returns true for correct images" do
      assert ImageProcessing::Vips.valid_image?(@portrait)
      assert ImageProcessing::Vips.valid_image?(copy_to_tempfile(@portrait)) # no extension
    end

    it "returns false for incorrect images" do
      refute ImageProcessing::Vips.valid_image?(fixture_image("invalid.jpg"))
      refute ImageProcessing::Vips.valid_image?(copy_to_tempfile(fixture_image("invalid.jpg"))) # no extension
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

    it "accepts sharpening options" do
      sharpened = @pipeline.resize_to_limit!(400, 400, sharpen: ImageProcessing::Vips::Processor::SHARPEN_MASK)
      normal    = @pipeline.resize_to_limit!(400, 400, sharpen: false)
      assert sharpened.size > normal.size, "Expected sharpened thumbnail to have bigger filesize than not sharpened thumbnail"
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

    it "accepts sharpening options" do
      sharpened = @pipeline.resize_to_fit!(400, 400, sharpen: ImageProcessing::Vips::Processor::SHARPEN_MASK)
      normal    = @pipeline.resize_to_fit!(400, 400, sharpen: false)
      assert sharpened.size > normal.size, "Expected sharpened thumbnail to have bigger filesize than not sharpened thumbnail"
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

    it "accepts sharpening options" do
      sharpened = @pipeline.resize_to_fill!(400, 400, sharpen: ImageProcessing::Vips::Processor::SHARPEN_MASK)
      normal   = @pipeline.resize_to_fill!(400, 400, sharpen: false)
      assert sharpened.size > normal.size, "Expected sharpened thumbnail to have bigger filesize than not sharpened thumbnail"
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

    it "produces correct image when shrinking" do
      result = @pipeline.convert("png").resize_and_pad!(400, 400, alpha: true)
      assert_similar fixture_image("pad.png"), result
      assert_equal 4, Vips::Image.new_from_file(result.path).bands

      transparent_png = @pipeline.add_alpha.convert!("png")
      result = @pipeline.source(transparent_png).resize_and_pad!(400, 400, alpha: true)
      assert_similar fixture_image("pad.png"), result
      assert_equal 4, Vips::Image.new_from_file(result.path).bands
    end

    it "produces correct image when enlarging" do
      @pipeline = ImageProcessing::Vips.source(@landscape)
      expected = fixture_image("pad-large.jpg")
      assert_similar expected, @pipeline.resize_and_pad!(1000, 1000, background: [0, 255, 0])
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

    it "accepts sharpening options" do
      sharpened = @pipeline.resize_and_pad!(400, 400, sharpen: ImageProcessing::Vips::Processor::SHARPEN_MASK)
      normal    = @pipeline.resize_and_pad!(400, 400, sharpen: false)
      assert sharpened.size > normal.size, "Expected sharpened thumbnail to have bigger filesize than not sharpened thumbnail"
    end
  end

  describe "#rotate" do
    before do
      @pipeline = ImageProcessing::Vips.source(@portrait)
    end

    it "rotates by muliples of 90" do
      assert_dimensions [600, 800], @pipeline.rotate!(0)
      assert_dimensions [800, 600], @pipeline.rotate!(90)
      assert_dimensions [600, 800], @pipeline.rotate!(180)
      assert_dimensions [800, 600], @pipeline.rotate!(270)
    end

    it "works for angles outside of 0-360 degrees" do
      assert_dimensions [600, 800], @pipeline.rotate!(360)
      assert_dimensions [800, 600], @pipeline.rotate!(450)
      assert_dimensions [800, 600], @pipeline.rotate!(-90)
    end

    it "rotates by arbitrary angle" do
      assert_dimensions [990, 990], @pipeline.rotate!(45)
    end

    it "accepts background color" do
      assert_dimensions [990, 990], @pipeline.rotate!(45, background: [0, 0, 0])
    end
  end

  describe "#composite" do
    before do
      @pipeline = ImageProcessing::Vips.source(@portrait)
    end

    it "accepts String, Pathname, and File object" do
      assert_similar fixture_image("composited.jpg"), @pipeline.composite!(@landscape)
      assert_similar fixture_image("composited.jpg"), @pipeline.composite!(@landscape.path)
      assert_similar fixture_image("composited.jpg"), @pipeline.composite!(Pathname(@landscape.path))
    end

    it "accepts Vips::Image object" do
      overlay = Vips::Image.new_from_file(@landscape.path)
      assert_similar fixture_image("composited.jpg"), @pipeline.composite!(overlay)
    end

    it "accepts :mode" do
      refute_similar fixture_image("composited.jpg"), @pipeline.composite!(@landscape, mode: "clear")
    end

    it "accepts :gravity" do
      result = @pipeline.composite!(@landscape, gravity: "centre")
      refute_similar fixture_image("composited.jpg"), result
      assert_dimensions [600, 800], result

      assert_raises(Vips::Error) { @pipeline.composite!(@landscape, gravity: "foo") }
    end

    it "accepts :offset" do
      result = @pipeline.composite!(@landscape, offset: [50, -50])
      refute_similar fixture_image("composited.jpg"), result
      assert_dimensions [600, 800], result
    end

    it "accepts additional options" do
      @pipeline.composite!(@landscape, compositing_space: :grey16)

      assert_raises(Vips::Error) { @pipeline.composite!(@landscape, compositing_space: :foo) }
    end

    it "accepts Vips::Image#composite parameters" do
      overlay  = Vips::Image.new_from_file(@landscape.path)
      original = @pipeline.custom! { |image| image.composite(overlay, :over) }

      assert_similar original, @pipeline.composite!(overlay, :over)
      assert_similar original, @pipeline.composite!(@landscape, :over)
      assert_similar original, @pipeline.composite!(@landscape.path, :over)
      assert_similar original, @pipeline.composite!(Pathname(@landscape.path), :over)

      assert_similar original, @pipeline.composite!([overlay], :over)
      assert_similar original, @pipeline.composite!([@landscape], :over)
      assert_similar original, @pipeline.composite!([@landscape.path], :over)
      assert_similar original, @pipeline.composite!([Pathname(@landscape.path)], :over)
    end
  end

  describe "resize-on-load" do
    it "retains order of operations" do
      result = ImageProcessing::Vips.source(@portrait)
        .resize_to_fit(400, 400)
        .crop(0, 0, 300, 300)
        .call

      assert_dimensions [300, 300], result

      result = ImageProcessing::Vips.source(@portrait)
        .crop(0, 0, 300, 300)
        .resize_to_fit(400, 400)
        .call

      assert_dimensions [400, 400], result
    end

    it "is skipped on loader options" do
      pipeline = ImageProcessing::Vips.source(fixture_image("invalid.jpg"))
        .loader(fail: true)
        .resize_to_fit(400, 400)

      error = assert_raises(Vips::Error) { pipeline.call }
      assert_match "Corrupt JPEG data", error.message
    end
  end
end
