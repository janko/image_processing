require "bundler/setup"

ENV["MT_NO_EXPECTATIONS"] = "1" # disable Minitest's expectations monkey-patches

require "minitest/autorun"
require "minitest/pride"

require "minitest/hooks/default"
require "minispec-metadata"

require "phashion" unless RUBY_ENGINE == "jruby"
require "vips"
require "mini_magick"

class MiniTest::Test
  def fixture_image(name)
    File.open("test/fixtures/#{name}", "rb")
  end

  def copy_to_tempfile(io, extension = nil)
    tempfile = Tempfile.new(["copy", *extension], binmode: true)
    IO.copy_stream(io, tempfile)
    io.rewind
    tempfile.tap(&:open)
  end

  def assert_similar(image1, image2)
    return if RUBY_ENGINE == "jruby" # Phashion has C extensions

    assert_operator distance(image1, image2), :<=, 4
  end

  def refute_similar(image1, image2)
    return if RUBY_ENGINE == "jruby" # Phashion has C extensions

    assert_operator distance(image1, image2), :>, 4
  end

  def assert_dimensions(dimensions, file)
    assert_equal dimensions, Vips::Image.new_from_file(file.path).size
  end

  def assert_type(type, file)
    assert_equal type, MiniMagick::Image.new(file.path).type
  end

  private

  def distance(image1, image2)
    a = Phashion::Image.new(image1.path)
    b = Phashion::Image.new(image2.path)

    a.distance_from(b).abs
  end
end

class Minitest::Spec
  def self.deprecated(name, &block)
    it("#{name} (deprecated)") do
      deprecated{instance_exec(&block)}
    end
  end

  def deprecated
    $stderr = StringIO.new
    yield
    $stderr = STDERR
  end
end
