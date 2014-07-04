# encoding: utf-8

# Required for parsing:

# This requirement is only made explicit in source files that aren’t
# included in the rackful “core”:
require 'rackful'


# Required for running:


module Rackful

  # Rack middleware that provides header spoofing.
  #
  # If you use this middleware, then clients are allowed to spoof an HTTP header
  # by specifying a `_http_SOME_HEADER=...` request parameter, for example
  # `http://example.com/some_resource?_http_DEPTH=infinity`.
  #
  # This can be useful if you want to specify certain request headers from within
  # a normal web browser.
  #
  # This middleware won’t work well together with Digest Authentication.
  # @example Using this middleware
  #   require_relative 'header_spoofing'
  #   use Rackful::HeaderSpoofing
  class HeaderSpoofing

    def initialize app
      @app = app
    end


    def call env
      new_query_string = env['QUERY_STRING'].
      split('&', -1).
      select {
        |p|
        p = p.split('=', 2)
        if  /\A_http_([a-z]+(?:[\-_][a-z]+)*)\z/i === p[0]
          header_name = p[0].gsub('-', '_').upcase[1..-1]
          env[header_name] = p[1]
          false
        else
          true
        end
      }.
      join('&')
      if env['QUERY_STRING'] != new_query_string
        env['rackful.header_spoofing.QUERY_STRING'] = env['QUERY_STRING']
        env['QUERY_STRING'] = new_query_string
      end
      @app.call env
    end

  end # Rackful::HeaderSpoofing
end # module Rackful
