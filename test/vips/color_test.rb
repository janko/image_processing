require "test_helper"
require "image_processing/vips/color"

describe ImageProcessing::Vips::Color do
  describe "#get" do
    it "returns rgb format of color" do
      color = ImageProcessing::Vips::Color.get('snow')
      assert_equal color, [255, 250, 250]
    end

    it "raise an error if color is not found" do
      assert_raises ImageProcessing::Vips::Color::InvalidColorName do
        ImageProcessing::Vips::Color.get('fake_one')
      end
    end
  end
end
