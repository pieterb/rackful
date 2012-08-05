Gem::Specification.new do |s|

  # Required properties:
  s.name        = 'rackful'
  s.version     = '0.1.2'
  s.summary     = "Library for building ReSTful web services with Rack"
  s.description = <<EOS
Rackful provides a minimal interface for developing ReSTful web services with
Rack and Ruby. Instead of writing HTTP method handlers, you'll implement
resource objects, which expose their state at URLs.

This version is NOT backward compatible with versions 0.0.x.
EOS
  s.files       = Dir[ '{*.md,example/*,lib/**/*}' ] +
                  %w( rackful.gemspec mkdoc.sh )

  # Optional properties:
  s.author      = 'Pieter van Beek'
  s.email       = 'rackful@djinnit.com'
  s.license     = 'Apache License 2.0'
  s.homepage    = 'http://pieterb.github.com/Rackful/'

  s.add_runtime_dependency 'rack', '>= 1.4'

end
