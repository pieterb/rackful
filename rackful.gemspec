Gem::Specification.new do |s|

  # Required properties:
  s.name        = 'rackful'
  s.version     = '0.2.1'
  s.summary     = "Library for building ReSTful web services with Rack"
  s.description = <<EOS
Rackful provides a minimal interface for developing ReSTful web services with
Rack and Ruby. Instead of writing HTTP method handlers, you’ll implement
resource objects, which expose their state at URLs.

This version is not backward compatible with v0.1.x.
EOS
  s.files       = Dir[ '{*.md,example/*.ru,lib/**/*.rb}' ] +
                  %w( rackful.gemspec mkdoc.sh )

  # Optional properties:
  s.author      = 'Pieter van Beek'
  s.email       = 'rackful@djinnit.com'
  s.license     = 'Apache License 2.0'
  s.homepage    = 'http://github.com/pieterb/Rackful'

  s.add_runtime_dependency 'rack',     '~> 1.5'
  s.add_runtime_dependency 'nokogiri', '~> 1.6'

end
