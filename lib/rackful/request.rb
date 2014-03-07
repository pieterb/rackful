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


  # Assert all <tt>If-*</tt> request headers.
  # @return [void]
  # @raise [HTTP304NotModified, HTTP400BadRequest, HTTP404NotFound, HTTP412PreconditionFailed]
  #   with the following meanings:
  # 
  #   -   `304 Not Modified`
  #   -   `400 Bad Request` Couldn't parse one or more <tt>If-*</tt> headers, or a
  #       weak validator comparison was requested for methods other than `GET` or
  #       `HEAD`.
  #   -   `404 Not Found`
  #   -   `412 Precondition Failed`
  # @see http://tools.ietf.org/html/rfc2616#section-13.3.3 RFC2616, section 13.3.3
  #   for details about weak and strong validator comparison.
  # @todo Implement support for the `If-Range:` header.
  def assert_if_headers
    #raise HTTP501NotImplemented, 'If-Range: request header is not supported.' \
    #  if env.key? 'HTTP_IF_RANGE'
    begin
      empty = resource.empty?
    rescue HTTP404NotFound => e
      empty = true
    end
    etag =
      if ! empty && resource.respond_to?(:get_etag)
        resource.get_etag
      else
        nil
      end
    last_modified =
      if ! empty && resource.respond_to?(:get_last_modified)
        resource.get_last_modified
      else
        nil
      end
    cond = {
      :match => if_match(),
      :none_match => if_none_match(),
      :modified_since => if_modified_since(),
      :unmodified_since => if_unmodified_since()
    }
    allow_weak = ['GET', 'HEAD'].include? self.request_method
    if empty
      if cond[:match]
        raise HTTP412PreconditionFailed, 'If-Match'
      elsif cond[:unmodified_since]
        raise HTTP412PreconditionFailed, 'If-Unmodified-Since'
      elsif cond[:modified_since]
        raise HTTP404NotFound
      end
    else
      if cond[:none_match] && validate_etag( etag, cond[:none_match] )
        if allow_weak
          raise HTTP304NotModified
        else
          raise HTTP412PreconditionFailed, 'If-None-Match'
        end
      elsif cond[:match] && ! validate_etag( etag, cond[:match] )
        raise HTTP412PreconditionFailed, 'If-Match'
      elsif cond[:unmodified_since]
        if ! last_modified || cond[:unmodified_since] < last_modified[0]
          raise HTTP412PreconditionFailed, 'If-Unmodified-Since'
        elsif last_modified && ! last_modified[1] && ! allow_weak &&
              cond[:unmodified_since] == last_modified[0]
          raise HTTP412PreconditionFailed, 'If-Unmodified-Since'
        end
      elsif cond[:modified_since]
        if ! last_modified || cond[:modified_since] >= last_modified[0]
          raise HTTP304NotModified
        elsif last_modified && ! last_modified[1] && !allow_weak &&
              cond[:modified_since] == last_modified[0]
          raise HTTP412PreconditionFailed, 'If-Modified-Since'
        end
      end
    end
  end


  private

  # @!method if_match()
  # Parses the HTTP/1.1 `If-Match:` header.
  # @return [nil, Array<String>]
  # @see http://tools.ietf.org/html/rfc2616#section-14.24 RFC2616, section 14.24
  # @see #if_none_match
  def if_match none = false
    header = env["HTTP_IF_#{ none ? 'NONE_' : '' }MATCH"]
    return nil unless header
    if %r{\A\s*\*\s*\z} === header
      return [ '*' ]
    elsif %r{\A(\s*(W/)?"([^"\\]|\\.)*"\s*,)+\z}m === ( header + ',' )
      return header.scan( %r{(?:W/)?"(?:[^"\\]|\\.)*"}m )
    end
    raise HTTP400BadRequest, "Couldn't parse If-#{ none ? 'None-' : '' }Match: #{header}"
  end


  # Parses the HTTP/1.1 `If-None-Match:` header.
  # @return [nil, Array<String>]
  # @see http://tools.ietf.org/html/rfc2616#section-14.26 RFC2616, section 14.26
  # @see #if_match
  def if_none_match
    if_match true
  end


  # @!method if_modified_since()
  # @return [nil, Time]
  # @see http://tools.ietf.org/html/rfc2616#section-14.25 RFC2616, section 14.25
  # @see #if_unmodified_since
  def if_modified_since unmodified = false
    header = env["HTTP_IF_#{ unmodified ? 'UN' : '' }MODIFIED_SINCE"]
    return nil unless header
    begin
      header = Time.httpdate( header )
    rescue ArgumentError
      raise HTTP400BadRequest, "Couldn't parse If-#{ unmodified ? 'Unmodified' : 'Modified' }-Since: #{header}"
    end
    header
  end


  # @return [nil, Time]
  # @see http://tools.ietf.org/html/rfc2616#section-14.28 RFC2616, section 14.28
  # @see #if_modified_since
  def if_unmodified_since
    if_modified_since true
  end


  # Does any of the tags in `etags` match `etag`?
  # @param etag [#to_s]
  # @param etags [#to_a]
  # @example
  #   etag = '"foo"'
  #   etags = [ 'W/"foo"', '"bar"' ]
  #   validate_etag etag, etags
  #   #> true
  # @return [Boolean]
  # @see http://tools.ietf.org/html/rfc2616#section-13.3.3 RFC2616 section 13.3.3
  #   for details about weak and strong validator comparison.
  def validate_etag etag, etags
    etag = etag.to_s
    match = etags.to_a.detect do
      |tag|
      tag = tag.to_s
      tag == '*' or
      tag == etag or
      'W/' +  tag == etag or
      'W/' + etag ==  tag
    end
    if  match and
        '*' != match and
        'W/' == etag[0,2] || 'W/' == match[0,2] and
        ! [ 'HEAD', 'GET' ].include? self.request_method
      raise HTTP400BadRequest, "Weak validators are only allowed for GET and HEAD requests."
    end
    !!match
  end


end # class Rackful::Request
end # module Rackful
