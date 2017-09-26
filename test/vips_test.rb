require "test_helper"
require "image_processing/vips"

describe ImageProcessing::Vips do
  include ImageProcessing::Vips

  def assert_similar(expected, actual)
    return if RUBY_ENGINE == "jruby"

    a = Phashion::Image.new(expected.path)
    b = Phashion::Image.new(actual.path)

    distance = a.distance_from(b).abs

    assert_operator distance, :<=, 2
  end

  def assert_dimensions(dimensions, file)
    assert_equal dimensions, Vips::Image.new_from_file(file.path).size
  end

  def assert_type(type, file)
    assert_equal type, File.extname(file.path)
  end

  before do
    @portrait = _copy_to_tempfile(fixture_image("portrait.jpg"))
    @landscape = _copy_to_tempfile(fixture_image("landscape.jpg"))
  end


  describe "#convert" do
    it "changes the image format" do
      result = convert(@portrait, "png")
      assert_type ".png", result
    end
  end

  describe "#auto_orient" do
    it "fixes the orientation of the image" do
      result = auto_orient(@portrait)
      assert_equal 1, Vips::Image.new_from_file(result.path).get("orientation")
    end
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

    it "produces correct image" do
      result = resize_to_limit(@portrait, 400, 400)
      assert_similar fixture_image("limit.jpg"), result
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

    it "produces correct image" do
      result = resize_to_fit(@portrait, 400, 400)
      assert_similar fixture_image("fit.jpg"), result
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
      @portrait = convert(@portrait, "png")
      result = resize_and_pad(@portrait, 400, 400, background: "red")
      assert_similar fixture_image("pad.jpg"), result
    end

    it "produces correct image when enlarging" do
      result = resize_and_pad(@landscape, 1000, 1000, background: "green")
      assert_similar fixture_image("pad-large.jpg"), result
    end
  end

  describe "#crop" do
    it "resizes the image to the given dimensions" do
      result = crop(@portrait, 50, 50)
      assert_dimensions [50, 50], result
    end

    it "crops the right area of the images from the center" do
      result = crop(@portrait, 50, 50, gravity: 'Center')
      assert_similar fixture_image("crop-center-vips.jpg"), result
    end
  end
end
