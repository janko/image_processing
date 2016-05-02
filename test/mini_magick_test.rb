require "test_helper"
require "image_processing/mini_magick"
require "stringio"

describe ImageProcessing::MiniMagick do
  include ImageProcessing::MiniMagick

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

  ["ImageMagick", "GraphicsMagick"].each do |cli|
    describe "with #{cli}", cli: cli.downcase.to_sym do
      around do |&block|
        MiniMagick.with_cli(metadata[:cli], &block)
      end

      describe "#convert!" do
        it "changes the image format" do
          result = convert!(@portrait, "png")
          assert_type "PNG", result
        end

        it "has a nondestructive version" do
          result = convert(@portrait, "png")
          assert_type "PNG", result
          assert File.exist?(@portrait.path)
        end

        it "yields the command object" do
          convert(@portrait, "png") { |cmd| @yielded = cmd }
          assert_kind_of MiniMagick::Tool, @yielded
        end
      end

      describe "#auto_orient!" do
        before do
          # Travis has old graphicsmagick version
          skip if metadata[:cli] == :graphicsmagick && ENV["CI"]
        end

        it "fixes the orientation of the image" do
          result = auto_orient!(@portrait)
          assert_equal "1", MiniMagick::Image.new(result.path).exif["Orientation"]
        end

        it "has a nondestructive version" do
          result = auto_orient(@portrait)
          assert File.exist?(@portrait.path)
        end

        it "yields the command object" do
          auto_orient(@portrait) { |cmd| @yielded = cmd }
          assert_kind_of MiniMagick::Tool, @yielded
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

        it "has a nondestructive version" do
          result = resize_to_limit(@portrait, 400, 400)
          assert_similar fixture_image("limit.jpg"), result
          assert File.exist?(@portrait.path)
        end

        it "yields the command object" do
          resize_to_limit(@portrait, 400, 400) { |cmd| @yielded = cmd }
          assert_kind_of MiniMagick::Tool, @yielded
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

        it "has a nondestructive version" do
          result = resize_to_fit(@portrait, 400, 400)
          assert_similar fixture_image("fit.jpg"), result
          assert File.exist?(@portrait.path)
        end

        it "yields the command object" do
          resize_to_fit(@portrait, 400, 400) { |cmd| @yielded = cmd }
          assert_kind_of MiniMagick::Tool, @yielded
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

        it "has a nondestructive version" do
          result = resize_to_fill(@portrait, 400, 400)
          assert_similar fixture_image("fill.jpg"), result
          assert File.exist?(@portrait.path)
        end

        it "yields the command object" do
          resize_to_fill(@portrait, 400, 400) { |cmd| @yielded = cmd }
          assert_kind_of MiniMagick::Tool, @yielded
        end
      end

      describe "#resize_and_pad!" do
        it "resizes and fills out the remaining space to fill out the given dimensions" do
          result = resize_and_pad!(@portrait, 400, 400, background: "red")
          assert_dimensions [400, 400], result
        end

        it "enlarges image and fills out the remaining space to fill out the given dimensions" do
          result = resize_and_pad!(@portrait, 1000, 1000, background: "red")
          assert_dimensions [1000, 1000], result
        end

        it "produces correct image" do
          @portrait = convert!(@portrait, "png")
          result = resize_and_pad!(@portrait, 400, 400, background: "red")
          assert_similar fixture_image("pad.jpg"), result
        end

        it "produces correct image when enlarging" do
          result = resize_and_pad!(@landscape, 1000, 1000, background: "green")
          assert_similar fixture_image("pad-large.jpg"), result
        end

        it "has a nondestructive version" do
          @portrait = convert!(@portrait, "png")
          result = resize_and_pad(@portrait, 400, 400, background: "red")
          assert_similar fixture_image("pad.jpg"), result
          assert File.exist?(@portrait.path)
        end

        it "yields the command object" do
          resize_and_pad(@portrait, 400, 400, background: "red") { |cmd| @yielded = cmd }
          assert_kind_of MiniMagick::Tool, @yielded
        end
      end

      describe "#resample" do
        it "downsamples high resolution images to low resolution" do
          result = resample!(@landscape, 30, 30)
          assert_resolution [30, 30], result
        end

        it "has a nondestructive version" do
          result = resample(@landscape, 30, 30)
          assert File.exist?(@landscape.path)
        end

        it "yields the command object" do
          resample(@landscape, 30, 30) { |cmd| @yielded = cmd }
          assert_kind_of MiniMagick::Tool, @yielded
        end
      end

      describe "#crop" do
        it "resizes the image to the given dimensions" do
          result = crop!(@portrait, 50, 50)
          assert_dimensions [50, 50], result
        end

        it "crops the right area of the images" do
          result = crop!(@portrait, 50, 50, 325, 425)
          assert_similar fixture_image("crop.jpg"), result
        end

        it "crops the right area of the images when a gravity is given" do
          result = crop!(@portrait, 50, 50, 30, 30, gravity: 'Center')
          assert_similar fixture_image("crop-center.jpg"), result
        end

        it "has a nondestructive version" do
          result = crop(@portrait, 50, 50, 325, 425)
          assert File.exist?(@portrait.path)
        end

        it "yields the command object" do
          crop(@portrait, 50, 50, 325, 425) { |cmd| @yielded = cmd }
          assert_kind_of MiniMagick::Tool, @yielded
        end
      end
    end
  end

  it "allows chaining" do
    result = resize_to_fit(@portrait, 400, 400)
    result = convert!(result, "png")

    assert_dimensions [300, 400], result
    assert_type "PNG", result
  end

  it "produces correct extension" do
    result = resize_to_fit(@portrait, 400, 400)
    assert_equal ".jpg", File.extname(result.path)
  end

  it "accepts StringIOs" do
    portrait = StringIO.new(@portrait.read)
    result = resize_to_fit(portrait, 400, 400)
    assert_dimensions [300, 400], result
  end

  it "rewinds the input file" do
    resize_to_fit(@portrait, 400, 400)
    assert_equal 0, @portrait.pos
  end

  it "module_function's the nondestructive aliases" do
    assert ImageProcessing::MiniMagick.respond_to?(:convert)
  end
end
