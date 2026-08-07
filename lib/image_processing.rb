require "image_processing/chainable"
require "image_processing/builder"
require "image_processing/pipeline"
require "image_processing/processor"
require "image_processing/version"

module ImageProcessing
  Error = Class.new(StandardError)

  # Method owners considered unsafe to dispatch to when a method name comes
  # from user input, because they expose Ruby's metaprogramming and shell
  # primitives (e.g. Kernel#send, Kernel#eval, BasicObject#instance_eval,
  # Kernel#system). Any name whose implementation is inherited from one of
  # these should never be treated as an image operation or a loader/saver
  # option.
  UNSAFE_METHOD_OWNERS = [BasicObject, Kernel, Object, Module].freeze

  # Whether calling +name+ on +receiver+ would dispatch to an unsafe Ruby core
  # method rather than a genuine operation. Used as a single, shared guard at
  # every place where a user-provided name is dispatched via +public_send+.
  def self.unsafe_method?(receiver, name)
    UNSAFE_METHOD_OWNERS.include?(receiver.method(name.to_s).owner)
  rescue NameError
    # An unknown name is not a Ruby core method, so it is safe to forward to
    # the receiver (which will reject it if it is not a real operation).
    false
  end

  autoload :MiniMagick, "image_processing/mini_magick"
  autoload :Vips, "image_processing/vips"
  autoload :Java2D, "image_processing/java2d"
  # ActiveSupport camelizes the Rails processor name :java2d as Java2d.
  autoload :Java2d, "image_processing/java2d"
end
