module StashMagic
  module ImageMagickStringBuilder
  
    def image_magick(attachment_name, style=nil, &block)
      @image_magick_strings = []
      instance_eval &block
      convert_string = @image_magick_strings.join(' ')
      convert(attachment_name, convert_string, style)
      @image_magick_strings = nil
      convert_string
    end
  
    def im_write(s)
      @image_magick_strings << s
    end
    def im_resize(width, height, geometry_option=nil, gravity=nil)
      if width.nil? || height.nil?
        @image_magick_strings << "-resize '#{width}x#{height}#{geometry_option}'"
      else
        @image_magick_strings << "-resize '#{width}x#{height}#{geometry_option}' -gravity #{gravity || 'center'} -extent #{width}x#{height}"
      end
    end
    def im_crop(width, height, x, y)
      @image_magick_strings <<  "-crop #{width}x#{height}+#{x}+#{y} +repage"
    end
    def im_negate
      @image_magick_strings << '-negate'
    end
    
  end
end