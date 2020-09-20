require "test_helper"
require "image_processing/vips"
require "pathname"

describe "ImageProcessing::Builder" do
  before do
    @portrait = fixture_image("portrait.jpg")
  end

  it "instruments pipeline execution" do
    pipeline = ImageProcessing::Vips
      .source(@portrait)
      .loader(shrink: 2)
      .resize_to_limit(500, 500)
      .saver(strip: true)
      .convert("png")

    instrumenter_called = false

    pipeline = pipeline.instrumenter do |**options, &block|
      instrumenter_called = true

      assert_equal @portrait,                        options[:source]
      assert_equal Hash[shrink: 2],                  options[:loader]
      assert_equal [[:resize_to_limit, [500, 500]]], options[:operations]
      assert_equal Hash[strip: true],                options[:saver]
      assert_equal "png",                            options[:format]

      block.call
    end

    pipeline.call

    assert instrumenter_called
  end

  it "handles instrumenter not returning pipeline result" do
    pipeline = ImageProcessing::Vips
      .source(@portrait)
      .instrumenter { |**, &block| block.call and :foo }

    assert_kind_of Tempfile, pipeline.call
  end
end
