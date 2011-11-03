F = ::File
D = ::Dir

require 'rubygems'
require 'bacon'

require 'sequel'
DB = Sequel.sqlite

require 'tempfile'

$:.unshift(F.dirname(__FILE__)+'/../lib')
require 'stash_magic'

class Treasure < ::Sequel::Model
  PUBLIC = F.expand_path(F.dirname(__FILE__)+'/public')
  ::StashMagic.with_public_root(PUBLIC)
  
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

# Make temporary public folder
D.mkdir(Treasure::PUBLIC) unless F.exists?(Treasure::PUBLIC)

describe 'StashMagic ImageMagickStringBuilder' do
  
  `convert rose: #{Treasure::PUBLIC}/rose.jpg` unless F.exists?(Treasure::PUBLIC+'/rose.jpg') # Use ImageMagick to build a tmp image to use
  `convert granite: #{Treasure::PUBLIC}/granite.gif` unless F.exists?(Treasure::PUBLIC+'/granite.gif') # Use ImageMagick to build a tmp image to use
  `convert rose: #{Treasure::PUBLIC}/rose.pdf` unless F.exists?(Treasure::PUBLIC+'/rose.pdf') # Use ImageMagick to build a tmp image to use
  `convert logo: #{Treasure::PUBLIC}/logo.pdf` unless F.exists?(Treasure::PUBLIC+'/logo.pdf')
  
  def mock_upload(uploaded_file_path, content_type, binary=false)
    n = F.basename(uploaded_file_path)
    f = ::Tempfile.new(n)
    f.set_encoding(Encoding::BINARY) if f.respond_to?(:set_encoding)
    f.binmode if binary
    ::FileUtils.copy_file(uploaded_file_path, f.path)
    {
      :filename => n, 
      :type => content_type,
      :tempfile => f
    }
  end
  
  before do
    @img = mock_upload(Treasure::PUBLIC+'/rose.jpg', 'image/jpeg', true)
    @img2 = mock_upload(Treasure::PUBLIC+'/granite.gif', 'image/gif', true)
    @pdf = mock_upload(Treasure::PUBLIC+'/rose.pdf', 'application/pdf', true)
    @pdf2 = mock_upload(Treasure::PUBLIC+'/logo.pdf', 'application/pdf', true)
  end
  
  it "Should have ImageMagick building strings correctly" do
    @t = Treasure.create(:map=>@img)
    
    @t.image_magick(:map, 'test.gif') do
      im_write("-negate")
      im_crop(200,100,20,10)
      im_resize(nil, 100)
    end.should=="-negate -crop 200x100+20+10 +repage -resize 'x100'"
    F.exists?(@t.file_path(:map,'test.gif',true)).should==true
    
    @t.image_magick(:map, 'test2.gif') do
      im_write("-negate")
      im_crop(200,100,20,10)
      im_resize(nil, 100, '>')
    end.should=="-negate -crop 200x100+20+10 +repage -resize 'x100>'"
    F.exists?(@t.file_path(:map,'test2.gif',true)).should==true
    
    @t.image_magick(:map, 'test3.gif') do
      im_write("-negate")
      im_crop(200,100,20,10)
      im_resize(200, 100, '^')
    end.should=="-negate -crop 200x100+20+10 +repage -resize '200x100^' -gravity center -extent 200x100"
    F.exists?(@t.file_path(:map,'test3.gif',true)).should==true
    
    @t.image_magick(:map, 'test4.gif') do
      im_write("-negate")
      im_crop(200,100,20,10)
      im_resize(200, 100, '^', 'North')
    end.should=="-negate -crop 200x100+20+10 +repage -resize '200x100^' -gravity North -extent 200x100"
    F.exists?(@t.file_path(:map,'test4.gif',true)).should==true    
  end
  
  ::FileUtils.rm_rf(Treasure::PUBLIC) if F.exists?(Treasure::PUBLIC)
  
end