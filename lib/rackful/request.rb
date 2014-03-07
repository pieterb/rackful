# encoding: utf-8

# Required for parsing:
require 'rackful/global.rb'

# Required for running:

module Rackful

# Subclass of {Rack::Request}, augmented for Rackful requests.
#
# This class mixes in module `StatusCodes` for convenience, as explained in the
# {StatusCodes StatusCodes documentation}.
class Request < Rack::Request

  include StatusCodes

  def initialize *args
    super( *args )
  end


  # Calls the code block passed to the {#initialize constructor}.
  # @param uri [URI::HTTP, String]
  # @return [Resource]
  # @raise [HTTP404NotFound]
  def resource_at( uri )
    uri = uri.kind_of?( URI::Generic ) ? uri.dup : URI(uri).normalize
    uri.query = nil
    raise "You forgot to include Rackful::Required in the middleware stack." \
      unless env['rackful.resource_registry']
    retval = env['rackful.resource_registry'].call( uri )
    raise HTTP404NotFound unless retval
    retval
  end

  # The current request’s main resource.
  #
  # As a side effect, {#canonical_uri} can be changed.
  # @return [Resource]
  # @raise [HTTP404NotFound] from {#resource_at}
  def resource
    @rackful_request_resource ||= begin
      c = URI(url).normalize
      retval = resource_at(c)
      c += retval.uri
      c.query = query_string unless query_string.empty?
      env['rackful.canonical_uri'] = c
      retval
    end
  end


  # Similar to the HTTP/1.1 `Content-Location:` header. Contains the canonical url
  # of the requested resource, which may differ from {#url}.
  # 
  # If parameter +full_path+ is provided, than this is used instead of the current
  # request’s full path (which is the path plus optional query string).
  # @return [URI::Generic]
  def canonical_uri
    env['rackful.canonical_uri'] || URI( url ).normalize
  end


  # The canonical url of the requested resource. This may differ from {#url}.
  # 
  # @todo Change URI::Generic into URI::HTTP
  # @param uri [URI::Generic, String]
  # @return [URI::Generic, String] `uri`
  #   def canonical_uri=( uri )
  #     env['rackful.canonical_uri'] =
  #       uri.kind_of?( URI::Generic ) ? uri.dup : URI( uri ).normalize
  #     uri
  #   end


  # Shortcut to {Rack::Utils.q_values}. Well, actually, we reimplemented it
  # because the implementation in {Rack::Utils} seems incomplete.
  # @return [Array<Array(type, quality)>]
  # @see Rack::Utils.q_values
  def q_values
    # This would be the “shortcut” implementation:
    #env['rackful.q_values'] ||= Rack::Utils.q_values(env['HTTP_ACCEPT'])
    # But here’s a full (and better) implementation:
    env['rackful.q_values'] ||= env['HTTP_ACCEPT'].to_s.split(/\s*,\s*/).map do
      |part|
      value, *parameters = part.split(/\s*;\s*/)
      quality = 1.0
      parameters.each do |p|
        quality = p[2..-1].to_f if p.start_with? 'q='
      end
      [value, quality]
    end
  end


  # Hash of acceptable media types and their qualities.
  #
  # This method parses the HTTP/1.1 `Accept:` header. If no acceptable media
  # types are provided, an empty Hash is returned.
  # @return [Hash{media_type => quality}]
  # @deprecated Use {#q_values} instead
  def accept
    env['rackful.accept'] ||= begin
      Hash[
        env['HTTP_ACCEPT'].to_s.split(',').collect do
          |entry|
          type, *options = entry.delete(' ').split(';')
          quality = 1
          options.each { |e|
            quality = e[2..-1].to_f if e.start_with? 'q='
          }
          [type, quality]
        end
      ]
    rescue
      {}
    end
  end # def accept


end # class Rackful::Request
end # module Rackful
