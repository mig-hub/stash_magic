require 'fileutils'
require 'stash_magic/image_magick_string_builder'
require 'stash_magic/storage_filesystem'
require 'stash_magic/storage_s3'

module StashMagic
  
  F = ::File
  D = ::Dir
  FU = ::FileUtils
  include ImageMagickStringBuilder
  
  # ====================
  # = Module Inclusion =
  # ====================
  
  class << self
    # Include and declare public root in one go
    def with_public_root(location, into=nil)
      into ||= into_from_backtrace(caller)
      into.__send__(:include, self)
      into.public_root = location
      into
    end
    # Include and declare bucket in one go
    def with_bucket(bucket, into=nil)
      into ||= into_from_backtrace(caller)
      into.__send__(:include, self)
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
  
  # ============
  # = Included =
  # ============
  
  def self.included(into)
    
    class << into
      attr_accessor :stash_reflection, :storage
      attr_reader :public_root, :bucket
      
      #include(ImageMagickStringBuilder)
      
      def public_root=(location)
        @public_root = location
        FU.mkdir_p(location+'/stash/'+self.name.to_s)
        include(StorageFilesystem)
        @storage = :filesystem
      end
      
      def bucket=(b)
        @bucket = b.to_s
        include(StorageS3)
        @storage = :s3
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
  
  # ===========
  # = Helpers =
  # ===========
  
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
  
  # =========
  # = Hooks =
  # =========
  
  def after_stash(attachment_name)
    current = self.__send__(attachment_name)
    convert(attachment_name, "-resize '100x75^' -gravity center -extent 100x75", 'stash_thumb.gif') if !current.nil? && current[:type][/^image\//]
  end
  
  def method_missing(m,*args)
    raise(NoMethodError, "You have to choose a strorage system") if self.class.storage.nil?
    super
  end
  
  private
  
  # Stolen from ERB
  def html_escape(s)
    s.to_s.gsub(/&/, "&amp;").gsub(/\"/, "&quot;").gsub(/>/, "&gt;").gsub(/</, "&lt;")
  end
  
  
end