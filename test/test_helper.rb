require "bundler/setup"

require "minitest/autorun"
require "minitest/pride"

require "minitest/hooks/default"
require "minispec-metadata"

require "phashion" unless RUBY_ENGINE == "jruby"

class MiniTest::Test
  def fixture_image(name)
    File.open("test/fixtures/#{name}", "rb")
  end
end
