require "test_helper"
require "vips"
require "image_processing/vips/gravity"

describe ImageProcessing::Vips::Gravity do
  before do
    file = File.new(fixture_image("portrait.jpg"))
    @portrait = Vips::Image.new_from_file(file.path)
  end

  describe "#get" do
    it "returns the expected gravity" do
      gravity = ImageProcessing::Vips::Gravity.get(@portrait, 200, 300, 'North')
      assert_equal gravity, [200, 0]
    end

    it "raise an error if invalid garvity value" do
      assert_raises ImageProcessing::Vips::Gravity::InvalidGravityValue do
        ImageProcessing::Vips::Gravity.get(@portrait, 200, 300, 'NorthSouth')
      end
    end
  end
end
