module ImageProcessing
  module Vips
    module Utils
      module_function

      def resize_image(image, width, height, min_or_max = :min)
        ratio = get_ratio image, width, height, min_or_max
        return image if ratio == 1
        image = if ratio > 1
                  image.resize(ratio, kernel: :nearest)
                else
                  image.resize(ratio, kernel: :cubic)
                end
        image
      end

      def get_ratio(image, width,height, min_or_max = :min)
        width_ratio = width.to_f / image.width
        height_ratio = height.to_f / image.height
        [width_ratio, height_ratio].send(min_or_max)
      end

      def extract_area(image, width, height)
        if image.width > width
          top = 0
          left = (image.width - width) / 2
        elsif image.height > height
          left = 0
          top = (image.height - height) / 2
        else
          left = 0
          top = 0
        end

        height = image.height if image.height < height
        width = image.width if image.width < width

        image.extract_area(left, top, width, height)
      end

      def destination_file(path, extension)
        if path && File.file?(path)
          File.new(path)
        else
          tempfile(extension)
        end
      end

      def tempfile(extension)
        Tempfile.new(["image_processing-vips", extension.to_s], binmode: true)
      end
    end
  end
end
