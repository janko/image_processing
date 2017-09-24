module ImageProcessing
  module Vips
    module Gravity
      class InvalidGravityValue < StandardError; end

      module_function

      def get(image, width, height, gravity)
        top = image.width - width
        left = image.height - height
        values = case gravity
                  when 'Center'
                    [(top / 2), (left / 2)]
                  when 'North'
                    [(top / 2), 0]
                  when 'East'
                    [top, (left / 2)]
                  when 'South'
                    [(top / 2), left]
                  when 'West'
                    [0, (left / 2)]
                  when 'NorthEast'
                    [top, 0]
                  when 'SouthEast'
                    [top,left]
                  when 'SouthWest'
                    [0, left]
                  when 'NorthWest'
                    [0, 0]
                  else
                    raise InvalidGravityValue
                  end
        values.map(&:abs)
      end
    end
  end
end
