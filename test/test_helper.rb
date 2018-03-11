require "bundler/setup"

require "minitest/autorun"
require "minitest/pride"

require "minitest/hooks/default"
require "minispec-metadata"

require "phashion" unless RUBY_ENGINE == "jruby"

class MiniTest::Test

  def fixture_image(name)
    File.open(fixture_path(name), "rb")
  end

  def fixture_path(name)
    "test/fixtures/#{name}"
  end

  # Creates a copy of the file and stores it into a Tempfile. Works for any
  # IO object that responds to `#read(length = nil, outbuf = nil)`.
  def copy_to_tempfile(path)
    tempfile = Tempfile.new(["test", File.extname(path)], binmode: true)
    IO.copy_stream(path, tempfile)
    tempfile.tap(&:open)
  end
end
