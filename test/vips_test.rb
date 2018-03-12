require "test_helper"
require "image_processing/vips"
require "mini_magick"

describe ImageProcessing::Vips do
  include ImageProcessing::Vips

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

  describe "#resize_to_limit" do
    it "resizes the image up to a given limit" do
      result = resize_to_limit(@portrait, 400, 400)
      assert_dimensions [300, 400], result
    end

    it "does not resize the image if it is smaller than the limit" do
      result = resize_to_limit(@portrait, 1000, 1000)
      assert_dimensions [600, 800], result
    end

    it "doesn't require both dimensions" do
      result = resize_to_limit(@portrait, 300, nil)
      assert_dimensions [300, 400], result

      result = resize_to_limit(@portrait, nil, 1000)
      assert_dimensions [600, 800], result
    end

    it "produces correct image" do
      result = resize_to_limit(@portrait, 400, 400)
      assert_similar fixture_image("limit.jpg"), result
    end

    it "accepts a block" do
      actual   = resize_to_limit(@portrait, 400, 400, &:invert)
      expected = vips(resize_to_limit(@portrait, 400, 400), &:invert)
      assert_similar expected, actual
    end

    it "accepts format" do
      result = resize_to_limit(@portrait, 400, 400, format: "png")
      assert_type "PNG", result
      assert_equal ".png", File.extname(result.path)
    end

    it "accepts additional thumbnail options" do
      result = resize_to_limit(@portrait, 400, 400, crop: :centre)
      assert_dimensions [400, 400], result
    end

    it "doesn't modify the input file" do
      resize_to_limit(@portrait, 400, 400)
      assert_equal fixture_image("portrait.jpg").read, @portrait.read
    end
  end

  describe "#resize_to_fit" do
    it "resizes the image to fit given dimensions" do
      result = resize_to_fit(@portrait, 400, 400)
      assert_dimensions [300, 400], result
    end

    it "enlarges image if it is smaller than given dimensions" do
      result = resize_to_fit(@portrait, 1000, 1000)
      assert_dimensions [750, 1000], result
    end

    it "doesn't require both dimensions" do
      result = resize_to_fit(@portrait, 300, nil)
      assert_dimensions [300, 400], result

      result = resize_to_fit(@portrait, nil, 1000)
      assert_dimensions [750, 1000], result
    end

    it "produces correct image" do
      result = resize_to_fit(@portrait, 400, 400)
      assert_similar fixture_image("fit.jpg"), result
    end

    it "accepts a block" do
      actual   = resize_to_fit(@portrait, 400, 400, &:invert)
      expected = vips(resize_to_fit(@portrait, 400, 400), &:invert)
      assert_similar expected, actual
    end

    it "accepts format" do
      result = resize_to_fit(@portrait, 400, 400, format: "png")
      assert_type "PNG", result
      assert_equal ".png", File.extname(result.path)
    end

    it "accepts additional thumbnail options" do
      result = resize_to_fit(@portrait, 400, 400, crop: :centre)
      assert_dimensions [400, 400], result
    end

    it "doesn't modify the input file" do
      resize_to_fit(@portrait, 400, 400)
      assert_equal fixture_image("portrait.jpg").read, @portrait.read
    end
  end

  describe "#resize_to_fill" do
    it "resizes and crops the image to fill out the given dimensions" do
      result = resize_to_fill(@portrait, 400, 400)
      assert_dimensions [400, 400], result
    end

    it "enlarges image and crops it if it is smaller than given dimensions" do
      result = resize_to_fill(@portrait, 1000, 1000)
      assert_dimensions [1000, 1000], result
    end

    it "produces correct image" do
      result = resize_to_fill(@portrait, 400, 400)
      assert_similar fixture_image("fill.jpg"), result
    end

    it "accepts a block" do
      actual   = resize_to_fill(@portrait, 400, 400, &:invert)
      expected = vips(resize_to_fill(@portrait, 400, 400), &:invert)
      assert_similar expected, actual
    end

    it "accepts format" do
      result = resize_to_fill(@portrait, 400, 400, format: "png")
      assert_type "PNG", result
      assert_equal ".png", File.extname(result.path)
    end

    it "accepts additional thumbnail options" do
      attention = resize_to_fill(@portrait, 400, 400, crop: :attention)
      centre    = resize_to_fill(@portrait, 400, 400, crop: :centre)
      refute_equal centre.read, attention.read
    end

    it "doesn't modify the input file" do
      resize_to_fill(@portrait, 400, 400)
      assert_equal fixture_image("portrait.jpg").read, @portrait.read
    end
  end

  describe "#resize_and_pad" do
    it "resizes and fills out the remaining space to fill out the given dimensions" do
      result = resize_and_pad(@portrait, 400, 400)
      assert_dimensions [400, 400], result
    end

    it "enlarges image and fills out the remaining space to fill out the given dimensions" do
      result = resize_and_pad(@portrait, 1000, 1000, background: "red")
      assert_dimensions [1000, 1000], result
    end

    it "produces correct image" do
      @portrait = vips(@portrait, format: "png")
      result = resize_and_pad(@portrait, 400, 400, background: "red")
      assert_similar fixture_image("pad.jpg"), result
    end

    it "produces correct image when enlarging" do
      result = resize_and_pad(@landscape, 1000, 1000, background: "green")
      assert_similar fixture_image("pad-large.jpg"), result
    end

    it "accepts a block" do
      actual   = resize_and_pad(@portrait, 400, 400, &:invert)
      expected = vips(resize_and_pad(@portrait, 400, 400), &:invert)
      assert_similar expected, actual
    end

    it "accepts format" do
      result = resize_and_pad(@portrait, 400, 400, format: "png")
      assert_type "PNG", result
      assert_equal ".png", File.extname(result.path)
    end

    it "accepts additional thumbnail options" do
      crop = resize_and_pad(@portrait, 400, 400, crop: :centre)
      pad = resize_and_pad(@portrait, 400, 400)
      refute_equal pad.read, crop.read
    end

    it "doesn't modify the input file" do
      resize_and_pad(@portrait, 400, 400)
      assert_equal fixture_image("portrait.jpg").read, @portrait.read
    end
  end

  describe "#crop" do
    it "resizes the image to the given dimensions" do
      result = crop(@portrait, 50, 50)
      assert_dimensions [50, 50], result
    end

    it "crops the right area of the images" do
      result = crop(@portrait, 50, 50, 325, 425)
      assert_similar fixture_image("crop.jpg"), result
    end

    it "accepts a block" do
      actual   = crop(@portrait, 50, 50, &:invert)
      expected = vips(crop(@portrait, 50, 50), &:invert)
      assert_similar expected, actual
    end

    it "accepts format" do
      result = crop(@portrait, 50, 50, format: "png")
      assert_type "PNG", result
      assert_equal ".png", File.extname(result.path)
    end

    it "doesn't modify the input file" do
      crop(@portrait, 50, 50)
      assert_equal fixture_image("portrait.jpg").read, @portrait.read
    end
  end

  describe "#vips" do
    it "accepts any object that responds to #read" do
      rotated = fixture_image("rotated.jpg")
      io = StringIO.new(rotated.read)
      actual = vips(io, &:autorot)
      expected = vips(rotated, &:autorot)
      assert_similar expected, actual
      assert_equal 0, io.pos
    end

    it "accepts format" do
      result = vips(@portrait, format: "png")
      assert_type "PNG", result
      assert_equal ".png", File.extname(result.path)
    end

    it "saves in JPEG format when extension is not known" do
      png = vips(@portrait, format: "png")
      result = vips(StringIO.new(png.read))
      assert_type "JPEG", result
      assert_equal ".jpg", File.extname(result.path)
    end

    it "fails with corrupted files" do
      corrupted = fixture_image("corrupted.jpg")
      assert_raises(Vips::Error) { vips(corrupted, &:autorot) }
    end

    it "automatically rotates files" do
      rotated = fixture_image("rotated.jpg")
      result = vips(rotated, &:invert)
      dimensions = Vips::Image.new_from_file(rotated.path).size
      assert_dimensions dimensions.reverse, result
    end

    it "accepts reading options" do
      dimensions = Vips::Image.new_from_file(@portrait.path).size
      resized = vips(@portrait, shrink: 2)
      assert_dimensions dimensions.map { |n| n / 2 }, resized
    end
  end
end
