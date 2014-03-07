# encoding: utf-8

# Required for parsing:

# This requirement is only made explicit in source files that aren’t
# included in the rackful “core”.
require 'rackful'

# Required for running:

module Rackful

# Rack middleware that handles conditional requests.
class Conditional
  
  include StatusCodes

  # Constructor. As required by Rack spec.
  def initialize app
    @app = app
  end


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
  def call env
    request = Request.new(env)
    begin
      resource = request.resource
      empty = resource.empty?
    rescue HTTP404NotFound => e
      resource = nil
      empty = true
    end
    raise HTTP501NotImplemented, 'If-Range: request header is not supported.' \
      if env.key? 'HTTP_IF_RANGE'
    etag = nil
    etag = resource.get_etag if ! empty && resource.respond_to?(:get_etag)
    last_modified = nil
    last_modified = resource.get_last_modified \
      if ! empty && resource.respond_to?(:get_last_modified)
    cond = {
      :match => if_match(request),
      :none_match => if_none_match(request),
      :modified_since => if_modified_since(request),
      :unmodified_since => if_unmodified_since(request)
    }
    allow_weak = ['GET', 'HEAD'].include? request.request_method
    if empty
      if cond[:match]
        raise HTTP412PreconditionFailed, 'If-Match'
      elsif cond[:unmodified_since]
        raise HTTP412PreconditionFailed, 'If-Unmodified-Since'
      elsif cond[:modified_since]
        raise HTTP404NotFound
      end
    else
      if cond[:none_match] && validate_etag( request, etag, cond[:none_match] )
        if allow_weak
          raise HTTP304NotModified
        else
          raise HTTP412PreconditionFailed, 'If-None-Match'
        end
      elsif cond[:match] && ! validate_etag( request, etag, cond[:match] )
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
    @app.call env
  end


  private


  # @overload if_match( request )
  #   Parses the HTTP/1.1 `If-Match:` header.
  #   @return [nil, Array<String>]
  #   @see http://tools.ietf.org/html/rfc2616#section-14.24 RFC2616, section 14.24
  #   @see #if_none_match
  def if_match request, none = false
    header = request.env["HTTP_IF_#{ none ? 'NONE_' : '' }MATCH"]
    return nil unless header
    if %r{\A\s*\*\s*\z} === header
      return [ '*' ]
    elsif %r{\A(\s*(W/)?"([^"\\]|\\.)*"\s*,)+\z}m === ( header + ',' )
      return header.scan( %r{(?:W/)?"(?:[^"\\]|\\.)*"}m )
    end
    raise HTTP400BadRequest, "Couldn't parse If-#{ none ? 'None-' : '' }Match: #{header}"
  end


  # Parses the HTTP/1.1 `If-None-Match:` header.
  # @param request [Rackful::Request]
  # @return [nil, Array<String>]
  # @see http://tools.ietf.org/html/rfc2616#section-14.26 RFC2616, section 14.26
  # @see #if_match
  def if_none_match request
    if_match request, true
  end


  # @overload if_modified_since( request )
  #   @param request [Rackful::Request]
  #   @return [nil, Time]
  #   @see http://tools.ietf.org/html/rfc2616#section-14.25 RFC2616, section 14.25
  #   @see #if_unmodified_since
  def if_modified_since request, unmodified = false
    header = request.env["HTTP_IF_#{ unmodified ? 'UN' : '' }MODIFIED_SINCE"]
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
  def if_unmodified_since request
    if_modified_since request, true
  end


  # Does any of the tags in `etags` match `etag`?
  # @param etag [#to_s]
  # @param etags [#to_a]
  # @param request [Rack::Request]
  # @example
  #   etag = '"foo"'
  #   etags = [ 'W/"foo"', '"bar"' ]
  #   validate_etag request, etag, etags
  #   #> true
  # @return [Boolean]
  # @see http://tools.ietf.org/html/rfc2616#section-13.3.3 RFC2616 section 13.3.3
  #   for details about weak and strong validator comparison.
  def validate_etag request, etag, etags
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
        ! [ 'HEAD', 'GET' ].include? request.request_method
      raise HTTP400BadRequest, "Weak validators are only allowed for GET and HEAD requests."
    end
    !!match
  end


end # Rackful::HeaderSpoofing
end # module Rackful
