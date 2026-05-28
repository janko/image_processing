require "bundler/setup"

ENV["MT_NO_EXPECTATIONS"] = "1" # disable Minitest's expectations monkey-patches

require "minitest/autorun"
require "minitest/pride"

require "minitest/hooks/default"
require "minispec-metadata"

ENV["VIPS_WARNING"] = "0" # disable libvips warnings

require "vips"
require "mini_magick"

# Faithful port of DHashVips::IDHash, inlined to avoid the upstream gem's
# fragile install-time test (which breaks on Ruby 4.0) and to make
# similarity assertions available on JRuby as well.
module PerceptualHash
  module_function

  SIZE = 8

  def fingerprint(path)
    image = Vips::Image.thumbnail(path, SIZE, height: SIZE, size: :force)
    image = image.flatten(background: 255) if image.has_alpha?
    image = image.colourspace("b-w")[0]
    rows = image.to_a.map(&:flatten)
    d1, i1 = signs_and_intensities(rows)
    d2, i2 = signs_and_intensities(rows.transpose)
    (((((i1 << SIZE * SIZE) | i2) << SIZE * SIZE) | d1) << SIZE * SIZE) | d2
  end

  def distance(a, b)
    ((a ^ b) & ((a | b) >> 2 * SIZE * SIZE)).to_s(2).count("1")
  end

  def signs_and_intensities(matrix)
    differences = matrix.zip(matrix.rotate(1)).flat_map do |r1, r2|
      r1.zip(r2).map { |a, b| a - b }
    end
    threshold = median(differences.map(&:abs).sort)
    signs = differences.inject(0) { |bits, d| (bits << 1) | (d < 0 ? 1 : 0) }
    intensities = differences.inject(0) { |bits, d| (bits << 1) | (d.abs >= threshold ? 1 : 0) }
    [signs, intensities]
  end

  def median(sorted)
    h = sorted.size / 2
    return sorted[h] if sorted[h] != sorted[h - 1]
    right = sorted.dup
    left = right.shift(h)
    right.shift if right.size > left.size
    return right.first if left.last != right.first
    return right.uniq[1] if left.count(left.last) > right.count(right.first)
    left.last
  end
end

class Minitest::Test
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
    assert_operator distance(image1, image2), :<=, 3
  end

  def refute_similar(image1, image2)
    assert_operator distance(image1, image2), :>, 3
  end

  def assert_dimensions(dimensions, file)
    assert_equal dimensions, Vips::Image.new_from_file(file.path).size
  end

  def assert_type(type, file)
    assert_equal type, MiniMagick::Image.new(file.path).type
  end

  private

  def distance(image1, image2)
    PerceptualHash.distance(
      PerceptualHash.fingerprint(image1.path),
      PerceptualHash.fingerprint(image2.path),
    )
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
