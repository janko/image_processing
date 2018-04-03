require "test_helper"
require "image_processing/mini_magick"
require "stringio"

describe "ImageProcessing::MiniMagick" do
  include ImageProcessing::MiniMagick

  before do
    @portrait  = fixture_image("portrait.jpg")
    @landscape = fixture_image("landscape.jpg")
  end

  it "applies imagemagick operations" do
    actual = ImageProcessing::MiniMagick.flip.call(@portrait)
    expected = Tempfile.new(["result", ".jpg"], binmode: true).tap do |tempfile|
      MiniMagick::Tool::Convert.new do |cmd|
        cmd << @portrait.path
        cmd.flip
        cmd << tempfile.path
      end
    end

    assert_similar expected, actual
  end

  it "applies macro operations" do
    actual = ImageProcessing::MiniMagick.resize_to_limit(400, 400).call(@portrait)
    expected = Tempfile.new(["result", ".jpg"], binmode: true).tap do |tempfile|
      MiniMagick::Tool::Convert.new do |cmd|
        cmd << @portrait.path
        cmd.resize("400x400")
        cmd << tempfile.path
      end
    end

    assert_similar expected, actual
  end

  it "applies appended options" do
    actual = ImageProcessing::MiniMagick.append("-resize", "400x400").call(@portrait)
    expected = Tempfile.new(["result", ".jpg"], binmode: true).tap do |tempfile|
      MiniMagick::Tool::Convert.new do |cmd|
        cmd << @portrait.path
        cmd.resize("400x400")
        cmd << tempfile.path
      end
    end

    assert_similar expected, actual
  end

  it "applies format" do
    result = ImageProcessing::MiniMagick.convert("png").call(@portrait)
    assert_equal ".png", File.extname(result.path)
    assert_type "PNG", result
  end

  it "accepts page" do
    tiff = Tempfile.new(["file", ".tiff"])
    MiniMagick::Tool::Convert.new do |convert|
      convert.merge! [@portrait.path, @portrait.path, @portrait.path]
      convert << tiff.path
    end

    processed = ImageProcessing::MiniMagick
      .source(tiff)
      .loader(page: 0)
      .convert!("jpg")

    refute_equal 0, processed.size
  end

  it "accepts geometry" do
    pipeline = ImageProcessing::MiniMagick.source(@portrait)
    assert_dimensions [300, 400], pipeline.loader(geometry: "400x400").call
  end

  it "auto orients by default" do
    result = ImageProcessing::MiniMagick.call(fixture_image("rotated.jpg"))
    assert_dimensions [600, 800], result

    result = ImageProcessing::MiniMagick.loader(auto_orient: false).call(fixture_image("rotated.jpg"))
    assert_dimensions [800, 600], result
  end

  it "applies loader options" do
    result = ImageProcessing::MiniMagick.loader(define: { jpeg: { size: "100x100" } }).call(@portrait)
    assert_dimensions [150, 200], result

    result = ImageProcessing::MiniMagick.loader(strip: true).call(@portrait)
    assert_empty MiniMagick::Image.new(result.path).exif

    result = ImageProcessing::MiniMagick.loader(strip: nil).call(@portrait)
    assert_empty MiniMagick::Image.new(result.path).exif

    result = ImageProcessing::MiniMagick.loader(strip: false).call(@portrait)
    assert_empty MiniMagick::Image.new(result.path).exif

    result = ImageProcessing::MiniMagick.loader(colorspace: "Gray").call(@portrait)
    assert_equal "Gray", MiniMagick::Image.new(result.path).data["colorspace"]

    result = ImageProcessing::MiniMagick.loader(set: ["comment", "This is a comment"]).call(@portrait)
    assert_equal "This is a comment", MiniMagick::Image.new(result.path).data["properties"]["comment"]
  end

  it "applies saver options" do
    result = ImageProcessing::MiniMagick.saver(define: { jpeg: { fancy_unsampling: "off", extent: "20KB" } }).call(@portrait)
    assert_operator result.size, :<, 20*1024

    result = ImageProcessing::MiniMagick.saver(strip: true).call(@portrait)
    assert_empty MiniMagick::Image.new(result.path).exif

    result = ImageProcessing::MiniMagick.saver(strip: nil).call(@portrait)
    assert_empty MiniMagick::Image.new(result.path).exif

    result = ImageProcessing::MiniMagick.saver(strip: false).call(@portrait)
    assert_empty MiniMagick::Image.new(result.path).exif

    result = ImageProcessing::MiniMagick.saver(colorspace: "Gray").call(@portrait)
    assert_equal "Gray", MiniMagick::Image.new(result.path).data["colorspace"]

    result = ImageProcessing::MiniMagick.saver(set: ["comment", "This is a comment"]).call(@portrait)
    assert_equal "This is a comment", MiniMagick::Image.new(result.path).data["properties"]["comment"]
  end

  it "accepts magick object as source" do
    magick = MiniMagick::Tool::Convert.new
    magick << fixture_image("rotated.jpg").path
    result = ImageProcessing::MiniMagick.source(magick).call
    assert_dimensions [600, 800], result
  end

  describe ".valid_image?" do
    it "returns true for correct images" do
      assert ImageProcessing::MiniMagick.valid_image?(@portrait)
      assert ImageProcessing::MiniMagick.valid_image?(copy_to_tempfile(@portrait)) # no extension
    end

    it "returns false for corrupted images" do
      refute ImageProcessing::MiniMagick.valid_image?(fixture_image("corrupted.jpg"))
      refute ImageProcessing::MiniMagick.valid_image?(copy_to_tempfile(fixture_image("corrupted.jpg"))) # no extension
    end

    deprecated "still supports the legacy API" do
      assert corrupted?(@portrait)
      refute corrupted?(fixture_image("corrupted.jpg"))

      assert ImageProcessing::MiniMagick.corrupted?(@portrait)
      refute ImageProcessing::MiniMagick.corrupted?(fixture_image("corrupted.jpg"))
    end
  end

  describe "#resize_to_limit" do
    before do
      @pipeline = ImageProcessing::MiniMagick.source(@portrait)
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

    it "produces correct image" do
      expected = fixture_image("limit.jpg")
      assert_similar expected, @pipeline.resize_to_limit!(400, 400)
    end

    it "accepts sharpening options" do
      sharpened = @pipeline.resize_to_limit!(400, 400, sharpen: { sigma: 1 })
      normal    = @pipeline.resize_to_limit!(400, 400, sharpen: false)
      assert sharpened.size > normal.size, "Expected sharpened thumbnail to have bigger filesize than not sharpened thumbnail"
    end

    deprecated "still supports the legacy API" do
      expected = @pipeline.resize_to_limit!(400, 400)

      assert_similar expected, resize_to_limit(@portrait, 400, 400)
      assert_similar expected, resize_to_limit!(copy_to_tempfile(@portrait, ".jpg"), 400, 400)
      assert_similar expected, resize_to_limit(StringIO.new(File.binread(@portrait.path)), 400, 400)

      assert_similar expected, ImageProcessing::MiniMagick.resize_to_limit(@portrait, 400, 400)
      assert_similar expected, ImageProcessing::MiniMagick.resize_to_limit!(copy_to_tempfile(@portrait, ".jpg"), 400, 400)
      assert_similar expected, ImageProcessing::MiniMagick.resize_to_limit(StringIO.new(File.binread(@portrait.path)), 400, 400)
    end
  end

  describe "#resize_to_fit" do
    before do
      @pipeline = ImageProcessing::MiniMagick.source(@portrait)
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

    it "produces correct image" do
      expected = fixture_image("fit.jpg")
      assert_similar expected, @pipeline.resize_to_fit!(400, 400)
    end

    it "accepts sharpening options" do
      sharpened = @pipeline.resize_to_fit!(400, 400, sharpen: { sigma: 1 })
      normal    = @pipeline.resize_to_fit!(400, 400, sharpen: false)
      assert sharpened.size > normal.size, "Expected sharpened thumbnail to have bigger filesize than not sharpened thumbnail"
    end

    deprecated "still supports the legacy API" do
      expected = @pipeline.resize_to_fit!(400, 400)

      assert_similar expected, resize_to_fit(@portrait, 400, 400)
      assert_similar expected, resize_to_fit!(copy_to_tempfile(@portrait, ".jpg"), 400, 400)
      assert_similar expected, resize_to_fit(StringIO.new(File.binread(@portrait.path)), 400, 400)

      assert_similar expected, ImageProcessing::MiniMagick.resize_to_fit(@portrait, 400, 400)
      assert_similar expected, ImageProcessing::MiniMagick.resize_to_fit!(copy_to_tempfile(@portrait, ".jpg"), 400, 400)
      assert_similar expected, ImageProcessing::MiniMagick.resize_to_fit(StringIO.new(File.binread(@portrait.path)), 400, 400)
    end
  end

  describe "#resize_to_fill" do
    before do
      @pipeline = ImageProcessing::MiniMagick.source(@portrait)
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

    it "accepts gravity" do
      centre    = @pipeline.resize_to_fill!(400, 400)
      northwest = @pipeline.resize_to_fill!(400, 400, gravity: "NorthWest")
      refute_similar centre, northwest
    end

    it "accepts sharpening options" do
      sharpened = @pipeline.resize_to_fill!(400, 400, sharpen: { sigma: 1 })
      normal    = @pipeline.resize_to_fill!(400, 400, sharpen: false)
      assert sharpened.size > normal.size, "Expected sharpened thumbnail to have bigger filesize than not sharpened thumbnail"
    end

    deprecated "still supports the legacy API" do
      expected = @pipeline.resize_to_fill!(400, 400)

      assert_similar expected, resize_to_fill(@portrait, 400, 400)
      assert_similar expected, resize_to_fill!(copy_to_tempfile(@portrait, ".jpg"), 400, 400)
      assert_similar expected, resize_to_fill(StringIO.new(File.binread(@portrait.path)), 400, 400)

      assert_similar expected, ImageProcessing::MiniMagick.resize_to_fill(@portrait, 400, 400)
      assert_similar expected, ImageProcessing::MiniMagick.resize_to_fill!(copy_to_tempfile(@portrait, ".jpg"), 400, 400)
      assert_similar expected, ImageProcessing::MiniMagick.resize_to_fill(StringIO.new(File.binread(@portrait.path)), 400, 400)
    end
  end

  describe "#resize_and_pad" do
    before do
      @pipeline = ImageProcessing::MiniMagick.source(@portrait)
    end

    it "resizes and fills out the remaining space to fill out the given dimensions" do
      assert_dimensions [400, 400], @pipeline.resize_and_pad!(400, 400)
    end

    it "enlarges image and fills out the remaining space to fill out the given dimensions" do
      assert_dimensions [1000, 1000], @pipeline.resize_and_pad!(1000, 1000)
    end

    it "produces correct image" do
      expected = fixture_image("pad.png")
      assert_similar expected, @pipeline.convert("png").resize_and_pad!(400, 400)

      png = @pipeline.convert!("png")
      assert_similar expected, @pipeline.source(png).resize_and_pad!(400, 400)
    end

    it "produces correct image when enlarging" do
      @pipeline = ImageProcessing::MiniMagick.source(@landscape)
      expected = fixture_image("pad-large.jpg")
      assert_similar expected, @pipeline.resize_and_pad!(1000, 1000, background: "green")
    end

    it "accepts gravity" do
      centre    = @pipeline.resize_and_pad!(400, 400)
      northwest = @pipeline.resize_and_pad!(400, 400, gravity: "NorthWest")
      refute_similar centre, northwest
    end

    it "accepts transparent color" do
      transparent = @pipeline.resize_and_pad!(400, 400, background: :transparent)
      default     = @pipeline.resize_and_pad!(400, 400)
      assert_similar transparent, default
    end

    it "accepts sharpening options" do
      sharpened = @pipeline.resize_and_pad!(400, 400, sharpen: { sigma: 1 })
      normal    = @pipeline.resize_and_pad!(400, 400, sharpen: false)
      assert sharpened.size > normal.size, "Expected sharpened thumbnail to have bigger filesize than not sharpened thumbnail"
    end

    deprecated "still supports the legacy API" do
      expected = @pipeline.resize_and_pad!(400, 400)

      assert_similar expected, resize_and_pad(@portrait, 400, 400)
      assert_similar expected, resize_and_pad!(copy_to_tempfile(@portrait, ".jpg"), 400, 400)
      assert_similar expected, resize_and_pad(StringIO.new(File.binread(@portrait.path)), 400, 400)

      assert_similar expected, ImageProcessing::MiniMagick.resize_and_pad(@portrait, 400, 400)
      assert_similar expected, ImageProcessing::MiniMagick.resize_and_pad!(copy_to_tempfile(@portrait, ".jpg"), 400, 400)
      assert_similar expected, ImageProcessing::MiniMagick.resize_and_pad(StringIO.new(File.binread(@portrait.path)), 400, 400)
    end
  end

  describe "#limits" do
    it "adds resource limits" do
      pipeline = ImageProcessing::MiniMagick.limits(time: 0.001).source(@portrait)
      exception = assert_raises(MiniMagick::Error) { pipeline.call }
      assert_includes exception.message, "time limit exceeded"
    end
  end

  describe "#auto_orient" do
    deprecated "still supports the legacy API" do
      auto_orient(@portrait)
      auto_orient!(copy_to_tempfile(@portrait, ".jpg"))
      auto_orient(StringIO.new(File.binread(@portrait.path)))

      ImageProcessing::MiniMagick.auto_orient(@portrait)
      ImageProcessing::MiniMagick.auto_orient!(copy_to_tempfile(@portrait, ".jpg"))
      ImageProcessing::MiniMagick.auto_orient(StringIO.new(File.binread(@portrait.path)))
    end
  end

  describe "#resample" do
    deprecated "still supports the legacy API" do
      resample(@portrait, 400, 400)
      resample!(copy_to_tempfile(@portrait, ".jpg"), 400, 400)
      resample(StringIO.new(File.binread(@portrait.path)), 400, 400)

      ImageProcessing::MiniMagick.resample(@portrait, 400, 400)
      ImageProcessing::MiniMagick.resample!(copy_to_tempfile(@portrait, ".jpg"), 400, 400)
      ImageProcessing::MiniMagick.resample(StringIO.new(File.binread(@portrait.path)), 400, 400)
    end
  end

  describe "#crop" do
    deprecated "still supports the legacy API" do
      crop(@portrait, 400, 400)
      crop!(copy_to_tempfile(@portrait, ".jpg"), 400, 400)
      crop(StringIO.new(File.binread(@portrait.path)), 400, 400)

      ImageProcessing::MiniMagick.crop(@portrait, 400, 400)
      ImageProcessing::MiniMagick.crop!(copy_to_tempfile(@portrait, ".jpg"), 400, 400)
      ImageProcessing::MiniMagick.crop(StringIO.new(File.binread(@portrait.path)), 400, 400)
    end
  end

  describe "#convert" do
    deprecated "still supports the legacy API" do
      assert_type "PNG", convert(@portrait, "png")
      assert_type "PNG", convert(StringIO.new(File.binread(@portrait.path)), "png")

      assert_type "PNG", ImageProcessing::MiniMagick.convert(@portrait, "png")
      assert_type "PNG", ImageProcessing::MiniMagick.convert(StringIO.new(File.binread(@portrait.path)), "png")
    end
  end
end
