require 'fileutils'

# A replacement for our current attachment system
# New requirements being:
# - More than one attachment per model
# - Easiest way to deal with folders (a bit like on the_wall)
# - Another way to deal with convert styles so that you can interract with it after saving the images (cropping for example)
# - Some facilities for pre-defined ImageMagick scripts
module StashMagic
  
  F = ::File
  D = ::Dir
  FU = ::FileUtils
  
  def self.included(into)
    class << into
      attr_reader :public_root
      attr_accessor :stash_reflection
      # Setter
      def public_root=(location)
        @public_root = location
        FU.mkdir_p(location+'/stash/'+self.name.to_s.underscore)
      end
      # Declare a stash entry
      def stash(name, options={})
        stash_reflection.store name.to_sym, options
        # Exemple of upload hash for attachments:
        # { :type=>"image/jpeg", 
        #   :filename=>"default.jpeg", 
        #   :tempfile=>#<File:/var/folders/J0/J03dF6-7GCyxMhaB17F5yk+++TI/-Tmp-/RackMultipart.12704.0>, 
        #   :head=>"Content-Disposition: form-data; name=\"model[attachment]\"; filename=\"default.jpeg\"\r\nContent-Type: image/jpeg\r\n", 
        #   :name=>"model[attachment]"
        # }
        #
        # GETTER
        define_method name.to_s+'='  do |upload_hash|
          return if upload_hash=="" # File in the form is unchanged
          
          if upload_hash.nil?
            destroy_files_for(name)
            super('')
          else
          
            @tempfile_path ||= {}
            @tempfile_path[name.to_sym] = upload_hash[:tempfile].path
            h = {
              :name => name.to_s + upload_hash[:filename][/\.[^.]+$/], 
              :type => upload_hash[:type], 
              :size => upload_hash[:tempfile].size
            }
            super(h.inspect)
            
          end
        end
        # SETTER
        define_method name.to_s do
          eval(super.to_s)
        end
      end
      
    end
    into.stash_reflection = {}
  end
  
  # Sugar
  def public_root
    self.class.public_root
  end
  
  # This method the path for images of a specific style(original by default)
  # The argument 'full' means it returns the absolute path(used to save files)
  # This could be a private method only used by file_url, but i keep it public just in case
  def file_path(full=false)
    raise "#{self.class}.public_root is not declared" if public_root.nil?
    "#{public_root if full}/stash/#{self.class.to_s.underscore}/#{self.id || 'tmp'}"
  end
     
  # Returns the url of an attachment in a specific style(original if nil)
  # The argument 'full' means it returns the absolute path(used to save files)
  def file_url(attachment_name, style=nil, full=false)
    f = send(attachment_name)
    return nil if f.nil?
    fn = style.nil? ? f[:name] : "#{attachment_name}.#{style}"
    "#{file_path(full)}/#{fn}"
  end
  
  # Build the image tag with all SEO friendly info
  # It's possible to add html attributes in a hash
  def build_image_tag(attachment_name, style=nil, html_attributes={})
    title = send(attachment_name+'_tooltip') rescue nil
    alt = send(attachment_name+'_alternative_text') rescue nil
    html_attributes = {:src => file_url(attachment_name, style), :title => title, :alt => alt}.update(html_attributes)
    "<img #{html_attributes.to_html_options} />"
  end
  
  # ===============
  # = ImageMagick =
  # ===============
  # Basic
  def convert(attachment_name, convert_steps="-resize 100x75^ -gravity center -extent 100x75", style='stash_thumb.gif')
    system "convert \"#{file_url(attachment_name, nil, true)}\" #{convert_steps} \"#{file_url(attachment_name, style, true)}\""
  end
  # IM String builder
  def image_magick(attachment_name, style, &block)
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
  # ===================
  # = End ImageMagick =
  # ===================
  
  def after_save
    super rescue nil
    unless (@tempfile_path.nil? || @tempfile_path.empty?)
      stash_path = file_path(true)
      D::mkdir(stash_path) unless F::exist?(stash_path)
      @tempfile_path.each do |k,v|
        url = file_url(k, nil, true)
        destroy_files_for(k, url) # Destroy previously saved files
        FU.move(v, url) # Save the new one
        FU.chmod(0777, url)
        after_stash(k)
      end
      # Reset in case we access to times the entry in the same session
      # Like setting an attachment and destroying it consecutively
      # Dummy ex:    Model.create(:img => file).update(:img => nil)
      @tempfile_path = nil
    end
  end
  
  def after_stash(attachment_name)
    current = self.send(attachment_name)
    convert(attachment_name) if !current.nil? && current[:type][/^image\//]
  end
  
  def destroy_files_for(attachment_name, url=nil)
    url ||= file_url(attachment_name, nil, true)
    D[url.sub(/\.[^.]+$/, '.*')].each {|f| FU.rm(f) }
  end
  alias destroy_file_for destroy_files_for
  
  def after_destroy
    super rescue nil
    p = file_path(true)
    FU.rm_rf(p) if F.exists?(p)
  end
  
  class << self
    # Include and declare public root in one go
    def with_public_root(location, into=nil)
      into ||= into_from_backtrace(caller)
      into.__send__(:include, StashMagic)
      into.public_root = location
      into
    end
    # Trick stolen from Innate framework
    # Allows not to pass self all the time
    def into_from_backtrace(backtrace)
      filename, lineno = backtrace[0].split(':', 2)
      regexp = /^\s*class\s+(\S+)/
      F.readlines(filename)[0..lineno.to_i].reverse.find{|ln| ln =~ regexp }
      const_get($1)
    end
  end
  
end