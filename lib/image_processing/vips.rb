require "vips"
require_relative "vips/color"
require_relative "vips/gravity"
require "tempfile"

module ImageProcessing
  module Vips
    module_function

    def convert!(image, format, &block)
      vips_image = ::Vips::Image.new_from_file image.path
      tmp_name = tmp_name(image.path, "_tmp.#{format}")
      vips_image.write_to_file(tmp_name)
      File.new(tmp_name)
    end

    def auto_orient!(image)
      with_ruby_vips(image) do |img|
        img.autorot
      end
    end

    def resize_to_limit!(image, width, height)
      with_ruby_vips(image) do |img|
        if width < img.width || height < img.height
          resize_image(img, width, height)
        else
          img
        end
      end
    end

    def resize_to_fit!(image, width, height)
      with_ruby_vips(image) do |img|
        resize_image(img, width, height)
      end
    end

    def resize_to_fill!(image, width, height)
      with_ruby_vips(image) do |img|
        img = resize_image img, width, height, :max
        extract_area(img, width, height)
      end
    end

    def resize_and_pad!(image, width, height, background: "transparent", gravity: "Center")
      with_ruby_vips(image) do |img|
        img = resize_image img, width, height
        top, left = Gravity.get(img, width, height, gravity)
        img = img.embed(top, left, width, height, {extend: :background, background: Color.get(background)})
        img
      end
    end

    def crop!(image, width, height, gravity: "NorthWest")
      with_ruby_vips(image) do |img|
        top, left = Gravity.get(img, width, height, gravity)
        img.crop top, left, width, height
      end
    end

    # Convert an image into a Vips::Image for the duration of the block,
    # and at the end return a File object.
    def with_ruby_vips(image)
      vips_image = yield ::Vips::Image.new_from_file image.path
      tmp_name_path = tmp_name(image.path)
      vips_image.write_to_file(tmp_name_path)
      File.new(tmp_name_path)
    end

    # Creates a copy of the file and stores it into a Tempfile. Works for any
    # IO object that responds to `#read(length = nil, outbuf = nil)`.
    def _copy_to_tempfile(file)
      extension = File.extname(file.path) if file.respond_to?(:path)
      tempfile = Tempfile.new(["vips", extension.to_s], binmode: true)
      IO.copy_stream(file, tempfile.path)
      file.rewind
      tempfile
    end

    def tmp_name(path, ext='_tmp\1')
      ext_regex = /(\.[[:alnum:]]+)$/
      path.sub(ext_regex, ext)
    end

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
  end
end
