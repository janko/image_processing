require_relative "lib/image_processing/version"

Gem::Specification.new do |spec|
  spec.name          = "image_processing"
  spec.version       = ImageProcessing::VERSION
  spec.authors       = ["Janko Marohnić"]
  spec.email         = ["janko.marohnic@gmail.com"]

  spec.summary       = "Set of higher-level helper methods for image processing."
  spec.description   = "Set of higher-level helper methods for image processing."
  spec.homepage      = "https://github.com/janko-m/image_processing"
  spec.license       = "MIT"

  spec.files         = Dir["README.md", "LICENSE.txt", "lib/**", "image_processing.gemspec"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "minitest", "~> 5.8"
  spec.add_development_dependency "minitest-hooks"
  spec.add_development_dependency "minispec-metadata"
  spec.add_development_dependency "mini_magick", ">= 4.3.5"
  spec.add_development_dependency "phashion"
end
