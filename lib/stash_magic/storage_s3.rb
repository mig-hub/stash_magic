module StashMagic
  module StorageS3
  
    # ===========
    # = Helpers =
    # ===========
  
    def bucket; self.class.bucket; end
  
    def s3_store_options(attachment_name)
      {:access=>:public_read}.update(self.class.stash_reflection[attachment_name][:s3_store_options]||{})
    end
  
    # This is the path of the instance
    def file_root; "#{self.class.to_s}/#{self.id || 'tmp'}"; end
     
    # This is the path of an attachment in a special style
    def file_path(attachment_name, style=nil)
      f = __send__(attachment_name)
      return nil if f.nil?
      fn = style.nil? ? f[:name] : "#{attachment_name}.#{style}"
      "#{file_root}/#{fn}"
    end
  
    # URL to access the file in browser
    # But it only gives a URL with no credentials, when the file is public
    # Otherwise it is better to use Model#s3object.url
    # Careful with the later if you have private files
    def file_url(attachment_name, style=nil, ssl=false)
      f = file_path(attachment_name, style)
      return nil if f.nil?
      "http#{'s' if ssl}://s3.amazonaws.com/#{bucket}/#{f}"
    end
  
    def s3object(attachment_name,style=nil)
      u = file_path(attachment_name,style)
      return nil if u.nil?
      AWS::S3::S3Object.find(u, bucket)
    end
  
    def get_file(attachment_name, style=nil)
      u = file_path(attachment_name,style)
      f = Tempfile.new('StashMagic_src')
      f.binmode
      f.write(AWS::S3::S3Object.value(u, bucket))
      f.rewind
      f
    end
  
    # =========
    # = Hooks =
    # =========
  
    def after_save
      super rescue nil
      unless (@tempfile_path.nil? || @tempfile_path.empty?)
        stash_path = file_root
        @tempfile_path.each do |k,v|
          url = file_path(k, nil)
          destroy_files_for(k, url) # Destroy previously saved files
          AWS::S3::S3Object.store(url, open(v), bucket, s3_store_options(k))
          after_stash(k)
        end
        # Reset in case we access two times the entry in the same session
        # Like setting an attachment and destroying it in a row
        # Dummy ex:    Model.create(:img => file).update(:img => nil)
        @tempfile_path = nil
      end
    end
  
    def destroy_files_for(attachment_name, url=nil)
      url ||= file_path(attachment_name, nil)
      AWS::S3::Bucket.objects(bucket, :prefix=>url.sub(/[^.]+$/, '')).each do |o|
        o.delete
      end
    end
    alias destroy_file_for destroy_files_for
  
    def after_destroy
      super rescue nil
      AWS::S3::Bucket.objects(bucket, :prefix=>file_root).each do |o|
        o.delete
      end
    end
  
    # ===============
    # = ImageMagick =
    # ===============
  
    def convert(attachment_name, convert_steps="", style=nil)
      @tempfile_path ||= {}
      tempfile_path = @tempfile_path[attachment_name.to_sym]
      if !tempfile_path.nil? && F.exists?(tempfile_path)
        src_path = tempfile_path
      else
        src_path = get_file(attachment_name).path
      end
      dest = Tempfile.new('StashMagic_dest')
      dest.binmode
      dest.close
      system "convert \"#{src_path}\" #{convert_steps} \"#{dest.path}\""
      AWS::S3::S3Object.store(file_path(attachment_name,style), dest.open, bucket, s3_store_options(attachment_name))
    end
    
  end
end