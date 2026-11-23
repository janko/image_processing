require "test_helper"
require "image_processing/vips"
require "pathname"
require "timeout"

describe "ImageProcessing::Vips" do
  before do
    @portrait  = fixture_image("portrait.jpg")
    @landscape = fixture_image("landscape.jpg")
    @square = fixture_image("square.jpg")
    @exif_portrait = fixture_image("exif_portrait.jpg")
  end

  it "applies vips operations" do
    actual = ImageProcessing::Vips.invert.call(@portrait)
    expected = Tempfile.new(["result", ".jpg"], binmode: true).tap do |tempfile|
      image = Vips::Image.new_from_file(@portrait.path)
      image = image.invert
      image.write_to_file(tempfile.path)
    end

    assert_similar expected, actual
  end

  it "applies macro operations" do
    actual = ImageProcessing::Vips.resize_to_limit(400, 400).call(@portrait)
    expected = Tempfile.new(["result", ".jpg"], binmode: true).tap do |tempfile|
      image = Vips::Image.new_from_file(@portrait.path)
      image = image.thumbnail_image(400, height: 400, size: :down)
      image.write_to_file(tempfile.path)
    end

    assert_similar expected, actual
  end

  it "allows changing metadata" do
    image = ImageProcessing::Vips
      .copy
      .set("icc-profile-data", "foobar")
      .set_type(Vips::BLOB_TYPE, "foo", "bar")
      .remove("exif-data")
      .call(@portrait, save: false)

    assert_equal "foobar", image.get("icc-profile-data")
    assert_equal "bar",    image.get("foo")

    assert_raises(Vips::Error) { image.get("exif-data") }
  end

  it "applies format" do
    result = ImageProcessing::Vips.convert("png").call(@portrait)
    assert_equal ".png", File.extname(result.path)
    assert_type "PNG", result
  end

  it "auto rotates by default" do
    result = ImageProcessing::Vips.call(fixture_image("rotated.jpg"))
    assert_dimensions [600, 800], result

    result = ImageProcessing::Vips.resize_to_limit(1000, 1000).call(fixture_image("rotated.jpg"))
    assert_dimensions [600, 800], result

    result = ImageProcessing::Vips.loader(fail: true).resize_to_limit(1000, 1000).call(fixture_image("rotated.jpg"))
    assert_dimensions [600, 800], result

    result = ImageProcessing::Vips.call(Vips::Image.new_from_file(fixture_image("rotated.jpg").path))
    assert_dimensions [600, 800], result

    result = ImageProcessing::Vips.loader(autorot: false).call(fixture_image("rotated.jpg"))
    assert_dimensions [800, 600], result

    result = ImageProcessing::Vips.loader(autorotate: false).call(fixture_image("rotated.jpg"))
    assert_dimensions [800, 600], result
  end

  it "accepts Vips::Image as source" do
    vips_image = Vips::Image.new_from_file(fixture_image("rotated.jpg").path)
    result = ImageProcessing::Vips.source(vips_image).call
    assert_dimensions [600, 800], result
  end

  it "applies loader options" do
    result = ImageProcessing::Vips.loader(shrink: 2).call(@portrait)
    assert_dimensions [300, 400], result
  end

  it "ignores loader options that are not defined" do
    png = ImageProcessing::Vips.convert("png").call(@portrait)
    ImageProcessing::Vips.loader(shrink: 2).call(png)
  end

  it "raises correct Vips::Error on unknown loader" do
    error = assert_raises(Vips::Error) { ImageProcessing::Vips.convert("jpg").call(Tempfile.new("")) }
    assert_includes error.message, "not a known file format"
  end

  it "accepts :loader" do
    error = assert_raises(Vips::Error) do
      ImageProcessing::Vips.loader(loader: :tiff).call(@portrait)
    end
    assert_match "Not a TIFF", error.message
  end

  it "applies saver options" do
    result = ImageProcessing::Vips.saver(strip: true).call(@portrait)
    refute_includes Vips::Image.new_from_file(result.path).get_fields, "exif-data"
  end

  it "converts :quality saver option to :Q" do
    result1 = ImageProcessing::Vips.saver(quality: 50).call(@portrait)
    result2 = ImageProcessing::Vips.saver(quality: 100).call(@portrait)
    assert result1.size < result2.size
  end

  it "ignores saver options that are not defined" do
    ImageProcessing::Vips.saver(Q: 85).convert("png").call(@portrait)
  end

  it "raises correct Vips::Error on unknown saver" do
    error = assert_raises(Vips::Error) { ImageProcessing::Vips.convert("foo").call(@portrait) }
    assert_match /is not a known file format|No known saver for/, error.message
  end

  it "accepts :saver" do
    result = ImageProcessing::Vips.saver(saver: :png).call(@portrait)
    assert_equal ".jpg", File.extname(result)
    assert_type "PNG", result
  end

  it "saves in the #convert format to a destination without an extension" do
    destination = Tempfile.new("destination")
    ImageProcessing::Vips.convert("png").call(@portrait, destination: destination.path)
    assert_type "PNG", destination
  end

  it "saves in the #convert format to a destination named as /dev/fd/N" do
    destination = Tempfile.new("destination")
    # libvips opens the destination read-write, and on macOS reopening a
    # /dev/fd/N descriptor can't widen its access mode, so the descriptor
    # must be opened read-write as well.
    File.open(destination.path, "w+b") do |file|
      ImageProcessing::Vips.convert("png").call(@portrait, destination: "/dev/fd/#{file.fileno}")
    end
    assert_type "PNG", destination
  end

  it "saves AVIF rather than HEIC in the #convert format to a destination without an extension" do
    begin
      Vips::Image.black(1, 1).heifsave_buffer(compression: :av1)
    rescue Vips::Error
      skip "libvips lacks an AV1 encoder"
    end
    destination = Tempfile.new("destination")
    ImageProcessing::Vips.convert("avif").call(@portrait, destination: destination.path)
    assert_equal "av1", Vips::Image.new_from_file(destination.path).get("heif-compression")
  end

  it "ignores saver options that the #convert format's saver does not define" do
    destination = Tempfile.new("destination")
    ImageProcessing::Vips.saver(compression: 9).convert("jpg").call(@portrait, destination: destination.path)
    assert_type "JPEG", destination
  end

  it "applies saver options in the #convert format to a destination without an extension" do
    low, high = Tempfile.new("low"), Tempfile.new("high")
    ImageProcessing::Vips.saver(quality: 10).convert("jpg").call(@portrait, destination: low.path)
    ImageProcessing::Vips.saver(quality: 100).convert("jpg").call(@portrait, destination: high.path)
    assert File.size(low.path) < File.size(high.path)
  end

  it "applies saver options named in a destination without an extension" do
    low, high = Tempfile.new("low"), Tempfile.new("high")
    ImageProcessing::Vips.convert("jpg").call(@portrait, destination: "#{low.path}[Q=10]")
    ImageProcessing::Vips.convert("jpg").call(@portrait, destination: "#{high.path}[Q=100]")
    assert File.size(low.path) < File.size(high.path)
  end

  it "prefers :saver to the #convert format" do
    destination = Tempfile.new("destination")
    ImageProcessing::Vips.saver(saver: :png).convert("jpg").call(@portrait, destination: destination.path)
    assert_type "PNG", destination
  end

  it "saves in the destination's extension rather than the #convert format" do
    destination = Tempfile.new(["destination", ".jpg"])
    ImageProcessing::Vips.convert("png").call(@portrait, destination: destination.path)
    assert_type "JPEG", destination
  end

  describe "IO source" do
    # Reads chunks through Enumerator#next, which resumes a Fiber, so like
    # Down::ChunkedIO it can only be read from the thread that created it.
    # Optionally raises after reading the given number of bytes.
    class FiberIO
      attr_reader :bytes_read

      def initialize(data, chunk_size: 16 * 1024, fail_after: nil)
        source = StringIO.new(data)

        @chunks = Enumerator.new do |yielder|
          while (chunk = source.read(chunk_size))
            yielder << chunk
            raise IOError, "connection reset" if fail_after && source.pos >= fail_after
          end
        end
        @buffer     = String.new
        @bytes_read = 0
      end

      def read(length)
        begin
          @buffer << @chunks.next while @buffer.bytesize < length
        rescue StopIteration
        end

        chunk = @buffer.slice!(0, length) unless @buffer.empty?
        @bytes_read += chunk.bytesize if chunk
        chunk
      end
    end

    around do |&block|
      Timeout.timeout(30) { super(&block) } # a deadlock would otherwise hang
    end

    def fiber_io(name, **options)
      FiberIO.new(File.binread("test/fixtures/#{name}"), **options)
    end

    it "streams IO objects that can only be read from their own thread" do
      result = ImageProcessing::Vips.resize_to_limit(400, 400).call(fiber_io("portrait.jpg"))
      assert_dimensions [300, 400], result
      assert_similar ImageProcessing::Vips.resize_to_limit(400, 400).call(@portrait), result
    end

    it "streams IO objects without resizing on load" do
      result = ImageProcessing::Vips.invert.call(fiber_io("portrait.jpg"))
      assert_similar ImageProcessing::Vips.invert.call(@portrait), result
    end

    it "accepts StringIO" do
      result = ImageProcessing::Vips.resize_to_fill(200, 200).call(StringIO.new(File.binread(@portrait.path)))
      assert_dimensions [200, 200], result
    end

    it "accepts IO objects with formats that require seeking" do
      png  = ImageProcessing::Vips.convert("png").call(@portrait)
      tiff = ImageProcessing::Vips.convert("tiff").call(@portrait)

      assert_dimensions [300, 400], ImageProcessing::Vips.resize_to_limit(400, 400).call(StringIO.new(png.read))
      assert_dimensions [300, 400], ImageProcessing::Vips.resize_to_limit(400, 400).call(StringIO.new(tiff.read))
    end

    it "accepts IO objects in #resize_to_cover" do
      result = ImageProcessing::Vips.resize_to_cover(300, 100).call(fiber_io("portrait.jpg"))
      assert_dimensions [300, 400], result
    end

    it "auto rotates IO objects" do
      assert_dimensions [600, 800], ImageProcessing::Vips.call(fiber_io("rotated.jpg"))
      assert_dimensions [300, 400], ImageProcessing::Vips.resize_to_limit(400, 400).call(fiber_io("rotated.jpg"))
    end

    it "saves IO objects to a destination" do
      destination = Tempfile.new(["destination", ".png"])
      ImageProcessing::Vips.resize_to_limit(400, 400).call(fiber_io("portrait.jpg"), destination: destination.path)
      assert_dimensions [300, 400], destination
      assert_type "PNG", destination
    end

    it "applies loader options to IO objects" do
      assert_dimensions [300, 400], ImageProcessing::Vips.loader(shrink: 2).call(fiber_io("portrait.jpg"))
    end

    it "ignores loader options to IO objects that are not defined" do
      png = ImageProcessing::Vips.convert("png").call(@portrait)
      assert_dimensions [600, 800], ImageProcessing::Vips.loader(shrink: 2).call(StringIO.new(png.read))
    end

    it "accepts :loader for IO objects" do
      error = assert_raises(Vips::Error) do
        ImageProcessing::Vips.loader(loader: :tiff).call(fiber_io("portrait.jpg"))
      end
      assert_match "Not a TIFF", error.message
    end

    it "returns an image from IO objects that doesn't need the IO object" do
      image = ImageProcessing::Vips.invert.call(fiber_io("portrait.jpg"), save: false)
      assert_equal [600, 800], image.size
      GC.start
      assert_equal 600 * 800 * 3, image.write_to_memory.bytesize
    end

    it "returns a resized image from IO objects" do
      image = ImageProcessing::Vips.resize_to_limit(400, 400).call(fiber_io("portrait.jpg"), save: false)
      assert_equal [300, 400], image.size
    end

    it "raises the error from reading the IO object rather than saving a truncated image" do
      io = fiber_io("portrait.jpg", fail_after: 32 * 1024)

      error = assert_raises(IOError) { ImageProcessing::Vips.resize_to_limit(400, 400).call(io) }
      assert_equal "connection reset", error.message
    end

    it "raises the error from reading the IO object without resizing on load" do
      io = fiber_io("portrait.jpg", fail_after: 32 * 1024)

      assert_raises(IOError) { ImageProcessing::Vips.invert.call(io) }
    end

    it "deletes the destination when reading the IO object fails" do
      destination = Dir::Tmpname.create(["destination", ".jpg"]) {}
      io = fiber_io("portrait.jpg", fail_after: 32 * 1024)

      assert_raises(IOError) { ImageProcessing::Vips.invert.call(io, destination:) }
      refute File.exist?(destination)
    end

    it "raises Vips::Error on invalid images" do
      error = assert_raises(Vips::Error) { ImageProcessing::Vips.call(StringIO.new("not an image")) }
      assert_includes error.message, "not in a known format"
    end

    it "stops reading the IO object when processing fails" do
      io = FiberIO.new("not an image" * 1_000_000, chunk_size: 1024)

      assert_raises(Vips::Error) { ImageProcessing::Vips.call(io) }
      assert_operator io.bytes_read, :<, 1_000_000
    end
  end

  describe ".valid_image?" do
    it "returns true for correct images" do
      assert ImageProcessing::Vips.valid_image?(@portrait)
      assert ImageProcessing::Vips.valid_image?(copy_to_tempfile(@portrait)) # no extension
    end

    it "returns false for incorrect images" do
      refute ImageProcessing::Vips.valid_image?(fixture_image("invalid.jpg"))
      refute ImageProcessing::Vips.valid_image?(copy_to_tempfile(fixture_image("invalid.jpg"))) # no extension
    end
  end

  describe "#resize_to_limit" do
    before do
      @pipeline = ImageProcessing::Vips.source(@portrait)
    end

    it "srinks image to fit the specified dimensions" do
      assert_dimensions [300, 400], @pipeline.resize_to_limit!(400, 400)
    end

    it "doesn't enlarge image if it's smaller than specified dimensions" do
      assert_dimensions [600, 800], @pipeline.resize_to_limit!(1000, 1000)
    end

    it "doesn't require both dimensions" do
      assert_dimensions [300, 400], @pipeline.resize_to_limit!(300, nil)
      assert_dimensions [600, 800], @pipeline.resize_to_limit!(800, nil)

      assert_dimensions [300, 400], @pipeline.resize_to_limit!(nil, 400)
      assert_dimensions [600, 800], @pipeline.resize_to_limit!(nil, 1000)
    end

    it "raises exception when neither dimension is specified" do
      assert_raises(ImageProcessing::Error) do
        @pipeline.resize_to_limit!(nil, nil)
      end
    end

    it "produces correct image" do
      expected = fixture_image("limit.jpg")
      assert_similar expected, @pipeline.resize_to_limit!(400, 400)
    end

    it "accepts thumbnail options" do
      assert_dimensions [400, 400], @pipeline.resize_to_limit!(400, 400, crop: :centre)
    end

    it "accepts sharpening options" do
      sharpened = @pipeline.resize_to_limit!(400, 400, sharpen: ImageProcessing::Vips::Processor::SHARPEN_MASK)
      normal    = @pipeline.resize_to_limit!(400, 400, sharpen: false)
      assert sharpened.size > normal.size, "Expected sharpened thumbnail to have bigger filesize than not sharpened thumbnail"
    end

    it "sharpening uses integer precision" do
      sharpened = @pipeline.resize_to_limit(400, 400, sharpen: true).call(save: false)
      assert_equal :uchar, sharpened.format
    end
  end

  describe "#resize_to_fit" do
    before do
      @pipeline = ImageProcessing::Vips.source(@portrait)
    end

    it "shrinks image to fit specified dimensions" do
      assert_dimensions [300, 400], @pipeline.resize_to_fit!(400, 400)
    end

    it "enlarges image if it's smaller than given dimensions" do
      assert_dimensions [750, 1000], @pipeline.resize_to_fit!(1000, 1000)
    end

    it "doesn't require both dimensions" do
      assert_dimensions [300, 400],  @pipeline.resize_to_fit!(300, nil)
      assert_dimensions [750, 1000], @pipeline.resize_to_fit!(750, nil)

      assert_dimensions [300, 400],  @pipeline.resize_to_fit!(nil, 400)
      assert_dimensions [750, 1000], @pipeline.resize_to_fit!(nil, 1000)
    end

    it "raises exception when neither dimension is specified" do
      assert_raises(ImageProcessing::Error) do
        @pipeline.resize_to_limit!(nil, nil)
      end
    end

    it "produces correct image" do
      expected = fixture_image("fit.jpg")
      assert_similar expected, @pipeline.resize_to_fit!(400, 400)
    end

    it "accepts thumbnail options" do
      assert_dimensions [400, 400], @pipeline.resize_to_fit!(400, 400, crop: :centre)
    end

    it "accepts sharpening options" do
      sharpened = @pipeline.resize_to_fit!(400, 400, sharpen: ImageProcessing::Vips::Processor::SHARPEN_MASK)
      normal    = @pipeline.resize_to_fit!(400, 400, sharpen: false)
      assert sharpened.size > normal.size, "Expected sharpened thumbnail to have bigger filesize than not sharpened thumbnail"
    end

    it "sharpening uses integer precision" do
      sharpened = @pipeline.resize_to_limit(400, 400, sharpen: true).call(save: false)
      assert_equal :uchar, sharpened.format
    end
  end

  describe "#resize_to_fill" do
    before do
      @pipeline = ImageProcessing::Vips.source(@portrait)
    end

    it "resizes and crops the image to fill out the given dimensions" do
      assert_dimensions [400, 400], @pipeline.resize_to_fill!(400, 400)
    end

    it "enlarges image and crops it if it's smaller than given dimensions" do
      assert_dimensions [1000, 1000], @pipeline.resize_to_fill!(1000, 1000)
    end

    it "produces correct image" do
      expected = fixture_image("fill.jpg")
      assert_similar expected, @pipeline.resize_to_fill!(400, 400)
    end

    it "accepts thumbnail options" do
      attention = @pipeline.resize_to_fill!(400, 400, crop: :attention)
      centre    = @pipeline.resize_to_fill!(400, 400, crop: :centre)
      refute_similar centre, attention
    end

    it "accepts sharpening options" do
      sharpened = @pipeline.resize_to_fill!(400, 400, sharpen: ImageProcessing::Vips::Processor::SHARPEN_MASK)
      normal   = @pipeline.resize_to_fill!(400, 400, sharpen: false)
      assert sharpened.size > normal.size, "Expected sharpened thumbnail to have bigger filesize than not sharpened thumbnail"
    end

    it "sharpening uses integer precision" do
      sharpened = @pipeline.resize_to_limit(400, 400, sharpen: true).call(save: false)
      assert_equal :uchar, sharpened.format
    end
  end

  describe "#resize_and_pad" do
    before do
      @pipeline = ImageProcessing::Vips.source(@portrait)
    end

    it "resizes and fills out the remaining space to fill out the given dimensions" do
      assert_dimensions [400, 400], @pipeline.resize_and_pad!(400, 400)
    end

    it "enlarges image and fills out the remaining space to fill out the given dimensions" do
      assert_dimensions [1000, 1000], @pipeline.resize_and_pad!(1000, 1000)
    end

    it "produces correct image when shrinking" do
      result = @pipeline.convert("png").resize_and_pad!(400, 400, alpha: true)
      assert_similar fixture_image("pad.png"), result
      assert_equal 4, Vips::Image.new_from_file(result.path).bands

      transparent_png = @pipeline.add_alpha.convert!("png")
      result = @pipeline.source(transparent_png).resize_and_pad!(400, 400, alpha: true)
      assert_similar fixture_image("pad.png"), result
      assert_equal 4, Vips::Image.new_from_file(result.path).bands
    end

    it "produces correct image when enlarging" do
      @pipeline = ImageProcessing::Vips.source(@landscape)
      expected = fixture_image("pad-large.jpg")
      assert_similar expected, @pipeline.resize_and_pad!(1000, 1000, background: [55, 126, 34])
    end

    it "accepts gravity" do
      centre    = @pipeline.resize_and_pad!(400, 400)
      northwest = @pipeline.resize_and_pad!(400, 400, gravity: "north-west")
      refute_similar centre, northwest
    end

    it "accepts thumbnail options" do
      pad  = @pipeline.resize_and_pad!(400, 400)
      crop = @pipeline.resize_and_pad!(400, 400, crop: :entropy)
      refute_similar pad, crop
    end

    it "accepts sharpening options" do
      sharpened = @pipeline.resize_and_pad!(400, 400, sharpen: ImageProcessing::Vips::Processor::SHARPEN_MASK)
      normal    = @pipeline.resize_and_pad!(400, 400, sharpen: false)
      assert sharpened.size > normal.size, "Expected sharpened thumbnail to have bigger filesize than not sharpened thumbnail"
    end

    it "sharpening uses integer precision" do
      sharpened = @pipeline.resize_to_limit(400, 400, sharpen: true).call(save: false)
      assert_equal :uchar, sharpened.format
    end
  end

  describe "#resize_to_cover" do
    before do
      @portrait_pipeline = ImageProcessing::Vips.source(@portrait)
      @landscape_pipeline = ImageProcessing::Vips.source(@landscape)
      @square_pipeline = ImageProcessing::Vips.source(@square)
      @exif_portrait_pipeline = ImageProcessing::Vips.source(@exif_portrait)
    end

    it "resizes the portrait image to fill out the given landscape dimensions" do
      assert_dimensions [300, 400], @portrait_pipeline.resize_to_cover!(300, 200)
    end

    it "resizes the portrait image to fill out the given portrait dimensions" do
      assert_dimensions [225, 300], @portrait_pipeline.resize_to_cover!(200, 300)
    end

    it "resizes the portrait image to fill out the given square dimensions" do
      assert_dimensions [300, 400], @portrait_pipeline.resize_to_cover!(300, 300)
    end

    it "resizes the landscape image to fill out the given portrait dimensions" do
      assert_dimensions [400, 300], @landscape_pipeline.resize_to_cover!(200, 300)
    end

    it "resizes the landscape image to fill out the given landscape dimensions" do
      assert_dimensions [300, 225], @landscape_pipeline.resize_to_cover!(300, 200)
    end

    it "resizes the landscape image to fill out the given square dimensions" do
      assert_dimensions [400, 300], @landscape_pipeline.resize_to_cover!(300, 300)
    end

    it "resizes the square image to fill out the given portrait dimensions" do
      assert_dimensions [300, 300], @square_pipeline.resize_to_cover!(200, 300)
    end

    it "resizes the square image to fill out the given landscape dimensions" do
      assert_dimensions [300, 300], @square_pipeline.resize_to_cover!(300, 200)
    end

    it "resizes the square image to fill out the given square dimensions" do
      assert_dimensions [300, 300], @square_pipeline.resize_to_cover!(300, 300)
    end

    it "produces correct image" do
      expected = fixture_image("cover.jpg")
      assert_similar expected, @portrait_pipeline.resize_to_cover!(300, 200)
    end

    it "accepts thumbnail options except :crop" do
      attention = @portrait_pipeline.resize_to_cover!(400, 400, crop: :attention)
      centre    = @portrait_pipeline.resize_to_cover!(400, 400, crop: :centre)
      assert_similar centre, attention
    end

    it "accepts sharpening options" do
      sharpened = @portrait_pipeline.resize_to_cover!(400, 400, sharpen: ImageProcessing::Vips::Processor::SHARPEN_MASK)
      normal   = @portrait_pipeline.resize_to_cover!(400, 400, sharpen: false)
      assert sharpened.size > normal.size, "Expected sharpened thumbnail to have bigger filesize than not sharpened thumbnail"
    end

    it "sharpening uses integer precision" do
      sharpened = @portrait_pipeline.resize_to_cover(400, 400, sharpen: true).call(save: false)
      assert_equal :uchar, sharpened.format
    end

    it "works correctly with EXIF orientation" do
      assert_dimensions [300, 617], @exif_portrait_pipeline.resize_to_cover!(300, 200)
    end
  end

  describe "#trim" do
    # Creates an image filled with the background, with a rectangle drawn on it.
    def image(background, rect: nil, rect_color: nil, size: [100, 100])
      image = (Vips::Image.black(*size) + background).cast(:uchar)
      image = image.copy(interpretation: :srgb) if background.size >= 3
      image = image.draw_rect(rect_color, *rect, fill: true) if rect
      image
    end

    def trim(image, *args, **options)
      ImageProcessing::Vips.source(image).trim(*args, **options).call(save: false)
    end

    it "trims background matching the top-left pixel" do
      white = image([255, 255, 255], rect: [20, 30, 10, 15], rect_color: [255, 0, 0])
      black = image([0, 0, 0], rect: [20, 30, 10, 15], rect_color: [255, 0, 0])

      assert_equal [10, 15], trim(white).size
      assert_equal [10, 15], trim(black).size
    end

    it "trims the correct area" do
      trimmed = trim image([255, 255, 255], rect: [20, 30, 10, 15], rect_color: [255, 0, 0])

      assert_equal [255, 0, 0], trimmed.getpoint(0, 0)
      assert_equal [255, 0, 0], trimmed.getpoint(9, 14)
    end

    it "trims grayscale images" do
      assert_equal [10, 15], trim(image([0], rect: [20, 30, 10, 15], rect_color: [255])).size
    end

    it "trims transparent background" do
      transparent = image([255, 255, 255, 0], rect: [20, 30, 10, 15], rect_color: [255, 0, 0, 255])

      assert_equal [10, 15], trim(transparent).size
    end

    it "trims transparent background around content of the same color" do
      transparent = image([0, 0, 0, 0], rect: [20, 30, 10, 15], rect_color: [0, 0, 0, 255])

      assert_equal [10, 15], trim(transparent).size
    end

    it "trims around content that differs in either color or alpha" do
      transparent = image([255, 255, 255, 0])
        .draw_rect([255, 0, 0, 255], 10, 10, 5, 5, fill: true)     # differs in color
        .draw_rect([255, 255, 255, 128], 50, 60, 5, 5, fill: true) # differs only in alpha

      assert_equal [45, 55], trim(transparent).size
    end

    it "keeps the image when it's entirely background" do
      assert_equal [100, 100], trim(image([255, 255, 255])).size
      assert_equal [100, 100], trim(image([0, 0, 0, 0])).size
    end

    it "keeps the image when it's too small to trim" do
      assert_equal [2, 100], trim(image([255, 255, 255], size: [2, 100])).size
    end

    it "accepts background color" do
      black = image([0, 0, 0], rect: [20, 30, 10, 15], rect_color: [255, 255, 255])

      assert_equal [100, 100], trim(black, background: [255, 255, 255]).size
      assert_equal [10, 15], trim(black, background: [0, 0, 0]).size
    end

    it "accepts background color with alpha" do
      transparent = image([0, 0, 0, 0], rect: [20, 30, 10, 15], rect_color: [0, 0, 0, 255])

      assert_equal [100, 100], trim(transparent, background: [0, 0, 0, 255]).size
      assert_equal [10, 15], trim(transparent, background: [0, 0, 0, 0]).size
    end

    it "accepts threshold" do
      faint = image([255, 255, 255], rect: [20, 30, 10, 15], rect_color: [250, 250, 250])

      assert_equal [100, 100], trim(faint).size
      assert_equal [10, 15], trim(faint, threshold: 2).size
    end

    it "accepts additional find_trim options" do
      skip "requires libvips 8.15+" unless Vips.at_least_libvips?(8, 15)

      # a single pixel is removed by the median filter unless line_art is set
      dot = image([255, 255, 255], rect: [20, 30, 1, 1], rect_color: [0, 0, 0])

      assert_equal [100, 100], trim(dot).size
      assert_equal [1, 1], trim(dot, line_art: true).size
    end

    it "works after resizing" do
      white = image([255, 255, 255], rect: [20, 30, 10, 15], rect_color: [255, 0, 0])
      trimmed = ImageProcessing::Vips.source(white).resize_to_fit(200, 200).trim.call(save: false)

      # resampling blurs the edges by a pixel
      assert_in_delta 20, trimmed.width, 1
      assert_in_delta 30, trimmed.height, 1
    end

    it "works with files" do
      assert_dimensions [600, 800], ImageProcessing::Vips.source(@portrait).trim.call
    end
  end

  describe "#rotate" do
    before do
      @pipeline = ImageProcessing::Vips.source(@portrait)
    end

    it "rotates by multiples of 90" do
      assert_dimensions [600, 800], @pipeline.rotate!(0)
      assert_dimensions [800, 600], @pipeline.rotate!(90)
      assert_dimensions [600, 800], @pipeline.rotate!(180)
      assert_dimensions [800, 600], @pipeline.rotate!(270)
    end

    it "works for angles outside of 0-360 degrees" do
      assert_dimensions [600, 800], @pipeline.rotate!(360)
      assert_dimensions [800, 600], @pipeline.rotate!(450)
      assert_dimensions [800, 600], @pipeline.rotate!(-90)
    end

    it "rotates by arbitrary angle" do
      assert_dimensions [990, 990], @pipeline.rotate!(45)
    end

    it "accepts background color" do
      assert_dimensions [990, 990], @pipeline.rotate!(45, background: [0, 0, 0])
    end
  end

  describe "#composite" do
    before do
      @pipeline = ImageProcessing::Vips.source(@portrait)
    end

    it "accepts String, Pathname, and File object" do
      assert_similar fixture_image("composited.jpg"), @pipeline.composite!(@landscape)
      assert_similar fixture_image("composited.jpg"), @pipeline.composite!(@landscape.path)
      assert_similar fixture_image("composited.jpg"), @pipeline.composite!(Pathname(@landscape.path))
    end

    it "accepts Vips::Image object" do
      overlay = Vips::Image.new_from_file(@landscape.path)
      assert_similar fixture_image("composited.jpg"), @pipeline.composite!(overlay)
    end

    it "accepts :mode" do
      refute_similar fixture_image("composited.jpg"), @pipeline.composite!(@landscape, mode: "clear")
    end

    it "accepts :gravity" do
      result = @pipeline.composite!(@landscape, gravity: "centre")
      refute_similar fixture_image("composited.jpg"), result
      assert_dimensions [600, 800], result

      assert_raises(Vips::Error) { @pipeline.composite!(@landscape, gravity: "foo") }
    end

    it "accepts :offset" do
      result = @pipeline.composite!(@landscape, offset: [50, -50])
      refute_similar fixture_image("composited.jpg"), result
      assert_dimensions [600, 800], result
    end

    it "accepts additional options" do
      @pipeline.composite!(@landscape, compositing_space: :grey16)

      assert_raises(Vips::Error) { @pipeline.composite!(@landscape, compositing_space: :foo) }
    end

    it "accepts Vips::Image#composite parameters" do
      overlay  = Vips::Image.new_from_file(@landscape.path)
      original = @pipeline.custom! { |image| image.composite(overlay, :over) }

      assert_similar original, @pipeline.composite!(overlay, :over)
      assert_similar original, @pipeline.composite!(@landscape, :over)
      assert_similar original, @pipeline.composite!(@landscape.path, :over)
      assert_similar original, @pipeline.composite!(Pathname(@landscape.path), :over)

      assert_similar original, @pipeline.composite!([overlay], :over)
      assert_similar original, @pipeline.composite!([@landscape], :over)
      assert_similar original, @pipeline.composite!([@landscape.path], :over)
      assert_similar original, @pipeline.composite!([Pathname(@landscape.path)], :over)
    end
  end

  describe "resize-on-load" do
    it "retains order of operations" do
      result = ImageProcessing::Vips.source(@portrait)
        .resize_to_fit(400, 400)
        .crop(0, 0, 300, 300)
        .call

      assert_dimensions [300, 300], result

      result = ImageProcessing::Vips.source(@portrait)
        .crop(0, 0, 300, 300)
        .resize_to_fit(400, 400)
        .call

      assert_dimensions [400, 400], result
    end

    it "is skipped on loader options" do
      pipeline = ImageProcessing::Vips.source(fixture_image("invalid.jpg"))
        .loader(fail: true)
        .resize_to_fit(400, 400)

      error = assert_raises(Vips::Error) { pipeline.call }
      assert_match "Corrupt JPEG data", error.message
    end
  end
end
