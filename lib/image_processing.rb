require "image_processing/chainable"
require "image_processing/builder"
require "image_processing/pipeline"
require "image_processing/processor"
require "image_processing/version"

module ImageProcessing
  Error = Class.new(StandardError)

  # Whether +name+ can be safely dispatched on +receiver+ when the name comes
  # from user input. A name is allowed if the receiver doesn't define it, in
  # which case it falls through to #method_missing and becomes an image
  # operation, or if it's defined by one of +allowed_owners+ (or a subclass).
  #
  # Any other method is rejected: Ruby core methods such as Kernel#send or
  # BasicObject#instance_eval, but also methods that other libraries mix into
  # every object, such as ActiveSupport's Object#try. Allowing only known
  # owners keeps the guard correct regardless of what else is loaded.
  #
  # Private methods are ignored, because public_send can't call them and
  # forwards them to #method_missing instead. This keeps CLI options named
  # like private Kernel methods (e.g. -format, -print) working.
  def self.allowed_method?(receiver, name, allowed_owners)
    owner = receiver.public_method(name.to_s).owner
    allowed_owners.any? { |allowed_owner| owner <= allowed_owner }
  rescue NameError
    true
  end

  autoload :MiniMagick, "image_processing/mini_magick"
  autoload :Vips, "image_processing/vips"
end
