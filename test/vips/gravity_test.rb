require "test_helper"
require "vips"
require "image_processing/vips/gravity"

describe ImageProcessing::Vips::Gravity do
  Gravity = ImageProcessing::Vips::Gravity

  before do
    @file     = fixture_image("portrait.jpg")
    @portrait = Vips::Image.new_from_file(@file.path)
  end

  describe "#initialize" do
    it "raises an error on invalid gravity value" do
      assert_raises(Gravity::Error) { Gravity.new("NorthSouth") }
    end
  end

  describe "#get_coords" do
    it "returns expected coordinates for Center" do
      gravity = Gravity.new("Center")
      coords  = gravity.get_coords(@portrait, 800, 1000)
      assert_equal [100, 100], coords
    end

    it "returns expected coordinates for North" do
      gravity = Gravity.new("North")
      coords  = gravity.get_coords(@portrait, 800, 1000)
      assert_equal [100, 0], coords
    end

    it "returns expected coordinates for NorthEast" do
      gravity = Gravity.new("NorthEast")
      coords  = gravity.get_coords(@portrait, 800, 1000)
      assert_equal [200, 0], coords
    end

    it "returns expected coordinates for East" do
      gravity = Gravity.new("East")
      coords  = gravity.get_coords(@portrait, 800, 1000)
      assert_equal [200, 100], coords
    end

    it "returns expected coordinates for SouthEast" do
      gravity = Gravity.new("SouthEast")
      coords  = gravity.get_coords(@portrait, 800, 1000)
      assert_equal [200, 200], coords
    end

    it "returns expected coordinates for South" do
      gravity = Gravity.new("South")
      coords  = gravity.get_coords(@portrait, 800, 1000)
      assert_equal [100, 200], coords
    end

    it "returns expected coordinates for SouthWest" do
      gravity = Gravity.new("SouthWest")
      coords  = gravity.get_coords(@portrait, 800, 1000)
      assert_equal [0, 200], coords
    end

    it "returns expected coordinates for West" do
      gravity = Gravity.new("West")
      coords  = gravity.get_coords(@portrait, 800, 1000)
      assert_equal [0, 100], coords
    end

    it "returns expected coordinates for NorthWest" do
      gravity = Gravity.new("NorthWest")
      coords  = gravity.get_coords(@portrait, 800, 1000)
      assert_equal [0, 0], coords
    end

    it "raise an error if image is larger than specified coords" do
      gravity = Gravity.new("Center")
      assert_raises(Gravity::Error) { gravity.get_coords(@portrait, 500, 500) }
    end
  end
end
