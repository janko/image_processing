require "bundler/setup"

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

  def assert_similar(expected, actual)
    return if RUBY_ENGINE == "jruby"

    a = Phashion::Image.new(expected.path)
    b = Phashion::Image.new(actual.path)

    distance = a.distance_from(b).abs

    assert_operator distance, :<=, 4
  end

  def assert_dimensions(dimensions, file)
    assert_equal dimensions, Vips::Image.new_from_file(file.path).size
  end

  def assert_type(type, file)
    assert_equal type, MiniMagick::Image.new(file.path).type
  end
end
