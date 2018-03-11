module ImageProcessing
  module Vips
    module Gravity
      class InvalidGravityValue < StandardError; end

      module_function

      def get(image, width, height, gravity)
        top = image.width - width
        left = image.height - height
        values = case gravity
                  when "Center"    then [(top / 2), (left / 2)]
                  when "North"     then [(top / 2), 0]
                  when "East"      then [top, (left / 2)]
                  when "South"     then [(top / 2), left]
                  when "West"      then [0, (left / 2)]
                  when "NorthEast" then [top, 0]
                  when "SouthEast" then [top,left]
                  when "SouthWest" then [0, left]
                  when "NorthWest" then [0, 0]
                  else
                    raise InvalidGravityValue
                  end
        values.map(&:abs)
      end
    end
  end
end
