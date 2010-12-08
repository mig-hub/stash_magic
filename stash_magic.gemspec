Gem::Specification.new do |s| 
  s.name = 'stash-magic'
  s.version = "0.0.3"
  s.platform = Gem::Platform::RUBY
  s.summary = "Simple Attachment Manager"
  s.description = "A simple attachment system that also handles thumbnails or other styles via ImageMagick. Originaly tested on Sequel ORM but purposedly easy to plug to something else."
  s.files = `git ls-files`.split("\n").sort
  s.test_files = ['spec.rb']
  s.require_path = '.'
  s.author = "Mickael Riga"
  s.email = "mig@mypeplum.com"
  s.homepage = "http://github.com/mig-hub/stash_magic"
end