require "test_helper"
require "mini_magick"
require "image_processing/vips"
require "stringio"

describe ImageProcessing::Vips do
  include ImageProcessing::Vips

  def assert_similar(expected, actual)
    return if RUBY_ENGINE == "jruby"

    a = Phashion::Image.new(expected.path)
    b = Phashion::Image.new(actual.path)

    distance = a.distance_from(b).abs

    assert_operator distance, :<, 2
  end

  def assert_dimensions(dimensions, file)
    assert_equal dimensions, MiniMagick::Image.new(file.path).dimensions
  end

  def assert_type(type, file)
    assert_equal type, MiniMagick::Image.new(file.path).type
  end

  def assert_resolution(resolution, file)
    actual_resolution = MiniMagick::Image.new(file.path).resolution
    # Travis has old imagemagick version
    actual_resolution = actual_resolution.select(&:nonzero?) if ENV["CI"]
    assert_equal resolution, actual_resolution
  end

  def fixture_image(name)
    File.open("test/fixtures/#{name}")
  end

  before do
    @portrait = _copy_to_tempfile(fixture_image("portrait.jpg"))
    @landscape = _copy_to_tempfile(fixture_image("landscape.jpg"))
  end


  describe "#convert!" do
    it "changes the image format" do
      result = convert!(@portrait, "png")
      assert_type "PNG", result
    end
  end

  describe "#auto_orient!" do
    it "fixes the orientation of the image" do
      result = auto_orient!(@portrait)
      assert_equal "1", MiniMagick::Image.new(result.path).exif["Orientation"]
    end
  end

  describe "#resize_to_limit!" do
    it "resizes the image up to a given limit" do
      result = resize_to_limit!(@portrait, 400, 400)
      assert_dimensions [300, 400], result
    end

    it "does not resize the image if it is smaller than the limit" do
      result = resize_to_limit!(@portrait, 1000, 1000)
      assert_dimensions [600, 800], result
    end

    it "produces correct image" do
      result = resize_to_limit!(@portrait, 400, 400)
      assert_similar fixture_image("limit.jpg"), result
    end
  end

  describe "#resize_to_fit!" do
    it "resizes the image to fit given dimensions" do
      result = resize_to_fit!(@portrait, 400, 400)
      assert_dimensions [300, 400], result
    end

    it "enlarges image if it is smaller than given dimensions" do
      result = resize_to_fit!(@portrait, 1000, 1000)
      assert_dimensions [750, 1000], result
    end

    it "produces correct image" do
      result = resize_to_fit!(@portrait, 400, 400)
      assert_similar fixture_image("fit.jpg"), result
    end
  end

  describe "#resize_to_fill!" do
    it "resizes and crops the image to fill out the given dimensions" do
      result = resize_to_fill!(@portrait, 400, 400)
      assert_dimensions [400, 400], result
    end

    it "enlarges image and crops it if it is smaller than given dimensions" do
      result = resize_to_fill!(@portrait, 1000, 1000)
      assert_dimensions [1000, 1000], result
    end

    it "produces correct image" do
      result = resize_to_fill!(@portrait, 400, 400)
      assert_similar fixture_image("fill.jpg"), result
    end
  end
end
