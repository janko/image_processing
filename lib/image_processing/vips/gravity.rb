module ImageProcessing
  module Vips
    class Gravity
      Error = Class.new(StandardError)

      COORDS = {
        "Center"    => -> (left, top) { [left / 2, top / 2] },
        "North"     => -> (left, top) { [left / 2, 0      ] },
        "NorthEast" => -> (left, top) { [left,     0      ] },
        "East"      => -> (left, top) { [left,     top / 2] },
        "SouthEast" => -> (left, top) { [left,     top    ] },
        "South"     => -> (left, top) { [left / 2, top    ] },
        "SouthWest" => -> (left, top) { [0,        top    ] },
        "West"      => -> (left, top) { [0,        top / 2] },
        "NorthWest" => -> (left, top) { [0,        0      ] },
      }

      def self.get_coords(image, width, height, gravity)
        new(gravity).get_coords(image, width, height)
      end

      attr_reader :gravity

      def initialize(gravity)
        raise Error, "invalid gravity value: #{gravity.inspect} (valid: #{COORDS.keys.join(", ")})" unless COORDS.key?(gravity)

        @gravity = gravity
      end

      def get_coords(image, width, height)
        raise Error, "image is larger than specified dimensions" unless image.width <= width && image.height <= height

        left = width  - image.width
        top  = height - image.height

        COORDS.fetch(gravity).call(left, top)
      end
    end
  end
end
