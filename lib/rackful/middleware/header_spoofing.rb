# encoding: utf-8
# Required for parsing:
require 'rackful'

# Required for running:


=begin markdown
Rack middleware that provides header spoofing.

If you use this middleware, then clients are allowed to spoof an HTTP header
by specifying a `_http_SOME_HEADER=...` request parameter, for example
`http://example.com/some_resource?_http_DEPTH=infinity`.

This can be useful if you want to specify certain request headers from within
a normal web browser.

This middleware won’t work well together with Digest Authentication.
@example Using this middleware
  require 'rackful/middleware/header_spoofing'
  use Rackful::HeaderSpoofing
=end
class Rackful::HeaderSpoofing

def initialize app
  @app = app
end

def call env
  original_query_string = env['QUERY_STRING']
  env['QUERY_STRING'] = original_query_string.
    split('&', -1).
    collect { |s| s.split('=', -1) }.
    select {
      |p|
      if  /\A_http_([a-z]+(?:[\-_][a-z]+)*)\z/i === p[0]
        header_name = p.shift.gsub('-', '_').upcase[1..-1]
        env[header_name] = p.join('=')
        false
      else
        true
      end
    }.
    collect { |p| p.join('=') }.
    join('&')
  if original_query_string != env['QUERY_STRING']
    env['rackful.header_spoofing.query_string'] ||= original_query_string
  end
  @app.call env
end

end # Rackful::HeaderSpoofing
