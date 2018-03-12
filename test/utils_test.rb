require "test_helper"
require "image_processing/utils"

describe ImageProcessing::Utils do
  Utils = ImageProcessing::Utils

  describe "#infer_dimensions" do
    it "returns dimensions if both are specified" do
      assert_equal [400, 500], Utils.infer_dimensions([400, 500], [800, 1000])
    end

    it "infers width if it's missing" do
      assert_equal [400, 500], Utils.infer_dimensions([nil, 500], [800, 1000])
    end

    it "applies ceiling rounding to width" do
      assert_equal [534, 600], Utils.infer_dimensions([nil, 600], [800, 900])
    end

    it "infers height if it's missing" do
      assert_equal [400, 500], Utils.infer_dimensions([400, nil], [800, 1000])
    end

    it "applies ceiling rounding to height" do
      assert_equal [500, 563], Utils.infer_dimensions([500, nil], [800, 900])
    end

    it "raises error when both dimensions are missing" do
      assert_raises(ArgumentError) { Utils.infer_dimensions([nil, nil], [800, 1000]) }
    end
  end
end
