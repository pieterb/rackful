Gem::Specification.new do |gem|
  gem.version            = File.read('VERSION.txt').chomp
  gem.date               = File.mtime('VERSION.txt').strftime('%Y-%m-%d')

  gem.name               = 'rackful'
  gem.homepage           = 'https://github.com/pieterb/rackful'
  gem.license            = 'Apache-2.0' if gem.respond_to?(:license=)
  gem.summary            = "Builds ReSTful web services with Rack"
  gem.description = <<-EOS
    Rackful provides a minimal interface for developing ReSTful web services with
    Rack and Ruby. Instead of writing HTTP method handlers, you’ll implement
    resource objects, which expose their state at URLs.

    This version is not backward compatible with v0.1.x.
  EOS

  gem.author             = 'Pieter van Beek'
  gem.email              = 'pieterb@djinnit.com'

  gem.platform           = Gem::Platform::RUBY
  gem.files              = %w( rackful.gemspec mkdoc.sh ) + Dir[ '{*.md,*.txt,example/*.ru,lib/**/*.rb}' ]

  gem.require_paths      = %w(lib)
  gem.test_files         = %w()

  gem.required_ruby_version = '>= 1.9.2'
  gem.add_runtime_dependency 'rack',       '~> 1.5'
  gem.add_runtime_dependency 'multi_json', '~> 1.10'
  #gem.add_development_dependency 'multi_xml',  '~> 0.5'
  #gem.add_development_dependency 'nokogiri'
  gem.add_development_dependency 'cucumber',   '~> 1.3'
  gem.add_development_dependency 'rack-test',  '~> 0.5'
  gem.add_development_dependency 'rspec-expectations', '~> 2.14'
  if defined?( RUBY_ENGINE ) and 'ruby' === RUBY_ENGINE
    gem.add_development_dependency 'yard'
    gem.add_development_dependency 'redcarpet'
  end
#  gem.post_install_message = <<EOS
#To use the built-in XHTML and JSON serializers and parsers, you'll have to 
#install multi_xml and multi_json respectively, by running:
#
#  gem install multi_xml
#  gem install multi_json
#  
#or, if you're using bundler, by adding them to your Gemfile:
#
#  gem 'multi_xml',  '~> 0.5'
#  gem 'multi_json', '~> 1.10'
#
#and running `bundle install`.
#EOS
end
