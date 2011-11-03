module StashMagic
  module StorageFilesystem
  
    # ===========
    # = Helpers =
    # ===========
  
    def public_root; self.class.public_root; end
  
    # This is the path of the instance
    # Full is when you want a computer path as opposed to a browser path
    def file_root(full=false)
      "#{public_root if full}/stash/#{self.class.to_s}/#{self.id || 'tmp'}"
    end
     
    # This is the path of an attachment in a special style
    # Full is when you want a computer path as opposed to a browser path
    def file_path(attachment_name, style=nil, full=false)
      f = __send__(attachment_name)
      return nil if f.nil?
      fn = style.nil? ? f[:name] : "#{attachment_name}.#{style}"
      "#{file_root(full)}/#{fn}"
    end
  
    # The actual URL for a link to the attachment
    # Here it is the same as file_path
    # But that gives a unified version for filesystem and S3
    def file_url(attachment_name, style=nil); file_path(attachment_name, style); end
  
    # =========
    # = Hooks =
    # =========
  
    def after_save
      super rescue nil
      unless (@tempfile_path.nil? || @tempfile_path.empty?)
        stash_path = file_root(true)
        D::mkdir(stash_path) unless F::exist?(stash_path)
        @tempfile_path.each do |k,v|
          url = file_path(k, nil, true)
          destroy_files_for(k, url) # Destroy previously saved files
          FU.move(v, url) # Save the new one
          FU.chmod(0777, url)
          after_stash(k)
        end
        # Reset in case we access two times the entry in the same session
        # Like setting an attachment and destroying it in a row
        # Dummy ex:    Model.create(:img => file).update(:img => nil)
        @tempfile_path = nil
      end
    end
  
    def destroy_files_for(attachment_name, url=nil)
      url ||= file_path(attachment_name, nil, true)
      D[url.sub(/\.[^.]+$/, '.*')].each {|f| FU.rm(f) }
    end
    alias destroy_file_for destroy_files_for
  
    def after_destroy
      super rescue nil
      p = file_root(true)
      FU.rm_rf(p) if F.exists?(p)
    end
  
    # ===============
    # = ImageMagick =
    # ===============
  
    def convert(attachment_name, convert_steps="", style=nil)
      system "convert \"#{file_path(attachment_name, nil, true)}\" #{convert_steps} \"#{file_path(attachment_name, style, true)}\""
    end
    
  end
end