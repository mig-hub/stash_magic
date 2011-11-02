require 'aws/s3'

module StashMagicS3
  
  F = ::File
  D = ::Dir
  FU = ::FileUtils
  
  def self.included(into)
    class << into
      attr_accessor :stash_reflection, :bucket
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
        # SETTER
        define_method name.to_s+'='  do |upload_hash|
          return if upload_hash=="" # File in the form is unchanged
          
          if upload_hash.nil?
            destroy_files_for(name) unless self.__send__(name).nil?
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
        # GETTER
        define_method name.to_s do |*args|
          eval(super(*args).to_s)
        end
      end
      
    end
    into.stash_reflection = {}
  end
  
  # Sugar
  def bucket
    raise "#{self.class}.bucket is not declared" if self.class.bucket.nil?
    self.class.bucket
  end
  
  # This method the path for images of a specific style(original by default)
  # The argument 'full' means it returns the absolute path(used to save files)
  # This could be a private method only used by file_url, but i keep it public just in case
  def file_root
    "#{self.class.to_s}/#{self.id || 'tmp'}"
  end
     
  # Returns the url of an attachment in a specific style(original if nil)
  # The argument 'full' means it returns the absolute path(used to save files)
  def file_path(attachment_name, style=nil)
    f = __send__(attachment_name)
    return nil if f.nil?
    fn = style.nil? ? f[:name] : "#{attachment_name}.#{style}"
    "#{file_root}/#{fn}"
  end
  
  # Like for the filesystem version
  # But it only gives a URL with no credentials, when the file is public
  # Otherwise it is better to use Model#s3object.url
  # Careful with the later if you have private files
  def file_url(attachment_name, style=nil)
    f = file_path(attachment_name, style)
    return nil if f.nil?
    "https://s3.amazonaws.com/#{bucket}/#{f}"
  end
  
  def s3object(attachment_name,style=nil)
    u = file_path(attachment_name,style)
    return nil if u.nil?
    AWS::S3::S3Object.find(u, bucket)
  end
  
  # Build the image tag with all SEO friendly info
  # It's possible to add html attributes in a hash
  def build_image_tag(attachment_name, style=nil, html_attributes={})
    title_field, alt_field = (attachment_name.to_s+'_tooltip').to_sym, (attachment_name.to_s+'_alternative_text').to_sym
    title = __send__(title_field) if columns.include?(title_field)
    alt = __send__(alt_field) if columns.include?(alt_field)
    html_attributes = {:src => file_url(attachment_name, style), :title => title, :alt => alt}.update(html_attributes)
    html_attributes = html_attributes.map do |k,v|
      %{#{k.to_s}="#{html_escape(v.to_s)}"}
    end.join(' ')
    
    "<img #{html_attributes} />"
  end
  
  # ===============
  # = ImageMagick =
  # ===============
  # Basic
  def convert(attachment_name, convert_steps="", style=nil)
    system "convert \"#{file_path(attachment_name, nil, true)}\" #{convert_steps} \"#{file_path(attachment_name, style, true)}\""
  end
  # IM String builder
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
  # ===================
  # = End ImageMagick =
  # ===================
  
  def after_save
    super rescue nil
    unless (@tempfile_path.nil? || @tempfile_path.empty?)
      stash_path = file_root
      @tempfile_path.each do |k,v|
        url = file_path(k, nil)
        destroy_files_for(k, url) # Destroy previously saved files
        AWS::S3::S3Object.store(url, open(v), bucket)
        #after_stash(k)
      end
      # Reset in case we access two times the entry in the same session
      # Like setting an attachment and destroying it in a row
      # Dummy ex:    Model.create(:img => file).update(:img => nil)
      @tempfile_path = nil
    end
  end
  
  def after_stash(attachment_name)
    current = self.__send__(attachment_name)
    convert(attachment_name, "-resize '100x75^' -gravity center -extent 100x75", 'stash_thumb.gif') if !current.nil? && current[:type][/^image\//]
  end
  
  def destroy_files_for(attachment_name, url=nil)
    url ||= file_path(attachment_name, nil)
    #D[url.sub(/\.[^.]+$/, '.*')].each {|f| FU.rm(f) }
    AWS::S3::Bucket.objects(bucket, :prefix=>url.sub(/[^.]+$/, '')).each do |o|
      o.delete
    end
  end
  alias destroy_file_for destroy_files_for
  
  def after_destroy
    super rescue nil
    p = file_root(true)
    FU.rm_rf(p) if F.exists?(p)
  end
  
  class << self
    # Include and declare public root in one go
    def with_bucket(bucket, into=nil)
      into ||= into_from_backtrace(caller)
      into.__send__(:include, StashMagicS3)
      into.bucket = bucket
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
  
  private
  
  # Stolen from ERB
  def html_escape(s)
    s.to_s.gsub(/&/, "&amp;").gsub(/\"/, "&quot;").gsub(/>/, "&gt;").gsub(/</, "&lt;")
  end
  
end