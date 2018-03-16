require "test_helper"
require "image_processing/vips"

describe "ImageProcessing::Pipeline" do
  before do
    @portrait = fixture_image("portrait.jpg")
  end

  it "accepts source" do
    pipeline = ImageProcessing::Vips.source(@portrait)
    assert_equal @portrait, pipeline.default_options[:source]
  end

  it "accepts format" do
    pipeline = ImageProcessing::Vips.convert("png")
    assert_equal "png", pipeline.default_options[:format]
  end

  it "accepts loader options" do
    pipeline = ImageProcessing::Vips.loader(shrink: 2)
    assert_equal Hash[shrink: 2], pipeline.default_options[:loader]

    pipeline = pipeline.loader(autorotate: true)
    assert_equal Hash[shrink: 2, autorotate: true], pipeline.default_options[:loader]
  end

  it "accepts saver options" do
    pipeline = ImageProcessing::Vips.saver(strip: true)
    assert_equal Hash[strip: true], pipeline.default_options[:saver]

    pipeline = pipeline.saver(Q: 100)
    assert_equal Hash[strip: true, Q: 100], pipeline.default_options[:saver]
  end

  it "accepts operations" do
    pipeline = ImageProcessing::Vips.shrink(2, 2)
    assert_equal [[:shrink, [2, 2]]], pipeline.default_options[:operations]

    pipeline = pipeline.invert
    assert_equal [[:shrink, [2, 2]], [:invert, []]], pipeline.default_options[:operations]
  end

  it "merges different options" do
    pipeline = ImageProcessing::Vips
      .resize_to_fill(400, 400)
      .convert("png")

    assert_equal [[:resize_to_fill, [400, 400]]], pipeline.default_options[:operations]
    assert_equal "png", pipeline.default_options[:format]
  end

  it "doesn't mutate the receiver" do
    pipeline_jpg = ImageProcessing::Vips.convert("jpg")
    pipeline_png = pipeline_jpg.convert("png")

    assert_equal "jpg", pipeline_jpg.default_options[:format]
    assert_equal "png", pipeline_png.default_options[:format]
  end

  it "executes processing on #call with source" do
    result = ImageProcessing::Vips.convert("png").call(@portrait)
    assert_instance_of Tempfile, result
    assert_type "PNG", result
  end

  it "executes processing on #call without source" do
    result = ImageProcessing::Vips.source(@portrait).convert("png").call
    assert_instance_of Tempfile, result
    assert_type "PNG", result
  end

  it "executes processing on bang operation method" do
    result = ImageProcessing::Vips.source(@portrait).convert!("png")
    assert_instance_of Tempfile, result
    assert_type "PNG", result

    result = ImageProcessing::Vips.source(@portrait).shrink!(2, 2)
    assert_instance_of Tempfile, result
    assert_dimensions [300, 400], result

    result = ImageProcessing::Vips.source(@portrait).resize_to_fill!(400, 400)
    assert_instance_of Tempfile, result
    assert_dimensions [400, 400], result
  end

  it "accepts a custom block" do
    actual   = ImageProcessing::Vips.custom(&:invert).call(@portrait)
    expected = ImageProcessing::Vips.invert.call(@portrait)
    assert_similar expected, actual
  end
end
