require "image_processing/vips/chainable"
require "image_processing/vips/pipeline"
require "image_processing/vips/processor"

require "image_processing/version"

module ImageProcessing
  module Vips
    Error = Class.new(StandardError)

    extend Chainable
  end
end
