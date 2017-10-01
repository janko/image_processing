require "bundler/setup"

require "minitest/autorun"
require "minitest/pride"

require "minitest/hooks/default"
require "minispec-metadata"

require "phashion" unless RUBY_ENGINE == "jruby"

def fixture_image(name)
  File.open("test/fixtures/#{name}")
end

# Creates a copy of the file and stores it into a Tempfile. Works for any
# IO object that responds to `#read(length = nil, outbuf = nil)`.
def _copy_to_tempfile(file)
  extension = File.extname(file.path) if file.respond_to?(:path)
  tempfile = Tempfile.new(["test", extension.to_s], binmode: true)
  IO.copy_stream(file, tempfile.path)
  file.rewind
  tempfile
end
