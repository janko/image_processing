require "test_helper"
require "image_processing/utils"
require "stringio"

describe ImageProcessing::Utils do
  Utils = ImageProcessing::Utils

  describe "#copy_to_tempfile" do
    it "returns a Tempfile" do
      io = StringIO.new("content")
      tempfile = Utils.copy_to_tempfile(io)
      assert_instance_of Tempfile, tempfile
    end

    it "copies content into the Tempfile" do
      io = StringIO.new("content")
      tempfile = Utils.copy_to_tempfile(io)
      assert_equal "content", tempfile.read
    end

    it "flushes content to disk" do
      io = StringIO.new("content")
      tempfile = Utils.copy_to_tempfile(io)
      assert_equal "content", File.read(tempfile.path)
    end

    it "opens the Tempfile in binary mode" do
      io = StringIO.new("content")
      tempfile = Utils.copy_to_tempfile(io)
      assert tempfile.binmode?
    end

    it "rewinds the IO object" do
      io = StringIO.new("content")
      tempfile = Utils.copy_to_tempfile(io)
      assert_equal 0, io.pos
    end

    it "calls a given block" do
      io = StringIO.new("content")
      Utils.copy_to_tempfile(io) { |tempfile| @block_called = true }
      assert @block_called
    end

    it "passes the Tempfile to the block" do
      io = StringIO.new("content")
      Utils.copy_to_tempfile(io) do |tempfile|
        assert_instance_of Tempfile, tempfile
      end
    end

    it "returns block return value" do
      io = StringIO.new("content")
      value = Utils.copy_to_tempfile(io) { |tempfile| 1 }
      assert_equal 1, value
    end

    it "closes and deletes the Tempfile at the end of the block" do
      io = StringIO.new("content")
      tempfile = Utils.copy_to_tempfile(io) do |tempfile|
        refute tempfile.closed?
        tempfile
      end
      assert tempfile.closed?
      assert_nil tempfile.path
    end
  end

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
