F = ::File
D = ::Dir

require 'rubygems'
require 'bacon'

require 'sequel'
DB = Sequel.sqlite

require 'tempfile'

require F.dirname(__FILE__)+'/stash_magic_s3'

class Treasure < ::Sequel::Model
  BUCKET = 'campbellhay-stashmagictest'
  ::StashMagicS3.with_bucket(BUCKET)
  
  plugin :schema
  set_schema do
    primary_key :id
    Integer :age
    String :map # jpeg
    String :map_tooltip
    String :map_alternative_text
    String :mappy # jpeg - Used to see if mappy files are not destroyed when map is (because it starts the same)
    String :instructions #pdf
  end
  create_table unless table_exists?
  
  stash :map
  stash :mappy
  stash :instructions
  
  def validate
    errors[:age] << "Not old enough" unless (self.age.nil? || self.age>10)
    errors[:instructions] << "Too big" if (!self.instructions.nil? && self.instructions[:size].to_i>46000)
  end
end

class BadTreasure < ::Sequel::Model
  include ::StashMagicS3
  
  plugin :schema
  set_schema do
    primary_key :id
    String :map # jpeg
    String :instructions #pdf
  end
  create_table unless table_exists?
end

# Make temporary public folder
#D.mkdir(Treasure::PUBLIC) unless F.exists?(Treasure::PUBLIC)

# =========
# = Tests =
# =========

describe ::StashMagicS3 do
  
  # `convert rose: #{Treasure::PUBLIC}/rose.jpg` unless F.exists?(Treasure::PUBLIC+'/rose.jpg') # Use ImageMagick to build a tmp image to use
  # `convert granite: #{Treasure::PUBLIC}/granite.gif` unless F.exists?(Treasure::PUBLIC+'/granite.gif') # Use ImageMagick to build a tmp image to use
  # `convert rose: #{Treasure::PUBLIC}/rose.pdf` unless F.exists?(Treasure::PUBLIC+'/rose.pdf') # Use ImageMagick to build a tmp image to use
  # `convert logo: #{Treasure::PUBLIC}/logo.pdf` unless F.exists?(Treasure::PUBLIC+'/logo.pdf')
  # 
  # def mock_upload(uploaded_file_path, content_type, binary=false)
  #   n = F.basename(uploaded_file_path)
  #   f = ::Tempfile.new(n)
  #   f.set_encoding(Encoding::BINARY) if f.respond_to?(:set_encoding)
  #   f.binmode if binary
  #   ::FileUtils.copy_file(uploaded_file_path, f.path)
  #   {
  #     :filename => n, 
  #     :type => content_type,
  #     :tempfile => f
  #   }
  # end
  # 
  # before do
  #   @img = mock_upload(Treasure::PUBLIC+'/rose.jpg', 'image/jpeg', true)
  #   @img2 = mock_upload(Treasure::PUBLIC+'/granite.gif', 'image/gif', true)
  #   @pdf = mock_upload(Treasure::PUBLIC+'/rose.pdf', 'application/pdf', true)
  #   @pdf2 = mock_upload(Treasure::PUBLIC+'/logo.pdf', 'application/pdf', true)
  # end
  
  it 'Should Include via Stash::with_bucket' do
    Treasure.bucket.should==Treasure::BUCKET
  end

  # it 'Should create stash and model folder when included' do
  #   F.exists?(Treasure::PUBLIC+'/stash/Treasure').should==true
  # end
  # 
  it "Should stash entries with Class::stash and have reflection" do
    Treasure.stash_reflection.keys.include?(:map).should==true
    Treasure.stash_reflection.keys.include?(:instructions).should==true
  end
  # 
  # it "Should give instance its own file_path" do
  #   # Normal path
  #   @t = Treasure.create
  #   @t.file_path.should=="/stash/Treasure/#{@t.id}"
  #   # Anonymous path
  #   Treasure.new.file_path.should=='/stash/Treasure/tmp'
  #   # Normal path full
  #   @t = Treasure.create
  #   @t.file_path(true).should==Treasure::PUBLIC+"/stash/Treasure/#{@t.id}"
  #   # Anonymous path full
  #   Treasure.new.file_path(true).should==Treasure::PUBLIC+'/stash/Treasure/tmp'
  # end
  # 
  # it "Should always raise on file_path if public_root is not declared" do
  #   lambda { BadTreasure.new.file_path }.should.raise(RuntimeError).message.should=='BadTreasure.public_root is not declared'
  # end
  # 
  # it "Should not raise on setters eval when value already nil" do
  #   Treasure.new.map.should==nil
  # end
  # 
  # it "Should have correct file_url values" do
  #   # Original with no file - so we are not sure about extention
  #   Treasure.new.file_url(:map).should==nil
  #   # Original with file but not saved
  #   Treasure.new(:map=>@img).file_url(:map).should=='/stash/Treasure/tmp/map.jpg'
  #   # Style with file but not saved
  #   Treasure.new(:map=>@img).file_url(:map, 'thumb.jpg').should=='/stash/Treasure/tmp/map.thumb.jpg' #not the right extention
  # end
  # 
  # it "Should save the attachments when creating entry" do
  #   @t = Treasure.create(:map => @img, :instructions => @pdf)
  #   @t.map.should=={:name=>'map.jpg',:type=>'image/jpeg',:size=>2074}
  #   F.exists?(Treasure::PUBLIC+'/stash/Treasure/'+@t.id.to_s+'/map.jpg').should==true
  #   F.exists?(Treasure::PUBLIC+'/stash/Treasure/'+@t.id.to_s+'/instructions.pdf').should==true
  #   F.exists?(Treasure::PUBLIC+'/stash/Treasure/'+@t.id.to_s+'/map.stash_thumb.gif').should==true
  #   F.exists?(Treasure::PUBLIC+'/stash/Treasure/'+@t.id.to_s+'/instructions.stash_thumb.gif').should==false
  # end
  # 
  # it "Should update attachment when updating entry" do
  #   @t = Treasure.create(:map => @img).update(:map=>@img2)
  #   @t.map.should=={:name=>'map.gif',:type=>'image/gif',:size=>7037}
  #   F.exists?(Treasure::PUBLIC+'/stash/Treasure/'+@t.id.to_s+'/map.gif').should==true
  #   F.exists?(Treasure::PUBLIC+'/stash/Treasure/'+@t.id.to_s+'/map.stash_thumb.gif').should==true
  #   F.exists?(Treasure::PUBLIC+'/stash/Treasure/'+@t.id.to_s+'/map.jpg').should==false
  # end
  # 
  # it "Should destroy its folder when destroying entry" do
  #   @t = Treasure.create(:map => @img)
  #   F.exists?(Treasure::PUBLIC+'/stash/Treasure/'+@t.id.to_s).should==true
  #   @t.destroy
  #   F.exists?(Treasure::PUBLIC+'/stash/Treasure/'+@t.id.to_s).should==false
  # end
  # 
  # it "Should be able to remove attachments when column is set to nil" do
  #   @t = Treasure.create(:map => @img, :mappy => @img2)
  #   @t.map.should=={:name=>'map.jpg',:type=>'image/jpeg',:size=>2074}
  #   @t.mappy.should=={:name=>'mappy.gif',:type=>'image/gif',:size=>7037}
  #   F.exists?(Treasure::PUBLIC+'/stash/Treasure/'+@t.id.to_s+'/map.jpg').should==true
  #   F.exists?(Treasure::PUBLIC+'/stash/Treasure/'+@t.id.to_s+'/mappy.gif').should==true
  #   F.exists?(Treasure::PUBLIC+'/stash/Treasure/'+@t.id.to_s+'/map.stash_thumb.gif').should==true
  #   @t.update(:map=>nil)
  #   @t.map.should==nil
  #   @t.mappy.should=={:name=>'mappy.gif',:type=>'image/gif',:size=>7037}
  #   F.exists?(Treasure::PUBLIC+'/stash/Treasure/'+@t.id.to_s+'/map.jpg').should==false
  #   F.exists?(Treasure::PUBLIC+'/stash/Treasure/'+@t.id.to_s+'/mappy.gif').should==true
  #   F.exists?(Treasure::PUBLIC+'/stash/Treasure/'+@t.id.to_s+'/map.stash_thumb.gif').should==false
  # end
  # 
  # it "Should be able to build image tags" do
  #   @t = Treasure.create(:map => @img, :map_alternative_text => "Wonderful")
  #   tag = @t.build_image_tag(:map)
  #   tag.should.match(/^<img\s.+\s\/>$/)
  #   tag.should.match(/\ssrc="\/stash\/Treasure\/#{@t.id}\/map.jpg"\s/)
  #   tag.should.match(/\salt="Wonderful"\s/)
  #   tag.should.match(/\stitle=""\s/)
  # end
  # 
  # it "Should be able to build image tags and override alt and title" do
  #   @t = Treasure.create(:map => @img, :map_alternative_text => "Wonderful")
  #   tag = @t.build_image_tag(:map,nil,:alt => 'Amazing & Beautiful Map')
  #   tag.should.match(/^<img\s.+\s\/>$/)
  #   tag.should.match(/\ssrc="\/stash\/Treasure\/#{@t.id}\/map.jpg"\s/)
  #   tag.should.match(/\salt="Amazing &amp; Beautiful Map"\s/)
  #   tag.should.match(/\stitle=""\s/)
  # end
  # 
  # it "Should be able to handle validations" do
  #   @t = Treasure.new(:instructions => @pdf2)
  #   @t.valid?.should==false
  #   F.exists?(Treasure::PUBLIC+'/stash/Treasure/'+@t.id.to_s+'/instructions.pdf').should==false
  #   @t.set(:instructions => @pdf, :age => 8)
  #   @t.valid?.should==false
  #   F.exists?(Treasure::PUBLIC+'/stash/Treasure/'+@t.id.to_s+'/instructions.pdf').should==false
  #   @t.set(:age => 12)
  #   @t.valid?.should==true
  #   @t.save
  #   F.exists?(Treasure::PUBLIC+'/stash/Treasure/'+@t.id.to_s+'/instructions.pdf').should==true
  # end
  # 
  # it "Should not raise when updating the entry with blank string - which means the attachment is untouched" do
  #   @t = Treasure.create(:instructions => @pdf)
  #   before = @t.instructions
  #   F.exists?(Treasure::PUBLIC+'/stash/Treasure/'+@t.id.to_s+'/instructions.pdf').should==true
  #   @t.update(:instructions=>"")
  #   @t.instructions.should==before
  #   F.exists?(Treasure::PUBLIC+'/stash/Treasure/'+@t.id.to_s+'/instructions.pdf').should==true
  # end
  # 
  # it "Should not raise when the setter tries to destroy files when there is nothing to destroy" do
  #   lambda { @t = Treasure.create(:instructions=>nil) }.should.not.raise
  #   lambda { @t.update(:instructions=>nil) }.should.not.raise
  # end
  # 
  # it "Should have ImageMagick string builder" do
  #   @t = Treasure.create(:map=>@img)
  #   
  #   @t.image_magick(:map, 'test.gif') do
  #     im_write("-negate")
  #     im_crop(200,100,20,10)
  #     im_resize(nil, 100)
  #   end.should=="-negate -crop 200x100+20+10 +repage -resize 'x100'"
  #   F.exists?(@t.file_url(:map,'test.gif',true)).should==true
  #   
  #   @t.image_magick(:map, 'test2.gif') do
  #     im_write("-negate")
  #     im_crop(200,100,20,10)
  #     im_resize(nil, 100, '>')
  #   end.should=="-negate -crop 200x100+20+10 +repage -resize 'x100>'"
  #   F.exists?(@t.file_url(:map,'test2.gif',true)).should==true
  #   
  #   @t.image_magick(:map, 'test3.gif') do
  #     im_write("-negate")
  #     im_crop(200,100,20,10)
  #     im_resize(200, 100, '^')
  #   end.should=="-negate -crop 200x100+20+10 +repage -resize '200x100^' -gravity center -extent 200x100"
  #   F.exists?(@t.file_url(:map,'test3.gif',true)).should==true
  #   
  #   @t.image_magick(:map, 'test4.gif') do
  #     im_write("-negate")
  #     im_crop(200,100,20,10)
  #     im_resize(200, 100, '^', 'North')
  #   end.should=="-negate -crop 200x100+20+10 +repage -resize '200x100^' -gravity North -extent 200x100"
  #   F.exists?(@t.file_url(:map,'test4.gif',true)).should==true    
  # end
  # 
  # it "Should be possible to overwrite the original image" do
  #   @t = Treasure.create(:map=>@img)
  #   url = @t.file_url(:map,nil,true)
  #   size_before = F.size(url)
  #   @t.convert(:map, '-resize 100x75')
  #   F.size(url).should.not==size_before
  # end
  # 
  # ::FileUtils.rm_rf(Treasure::PUBLIC) if F.exists?(Treasure::PUBLIC)

end
