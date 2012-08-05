# Required for parsing:
require 'rack'

# Required for running:


module Rackful

=begin markdown
Subclass of {Rack::Request}, augmented for Rackful requests.
@since 0.0.1
=end
class Request < Rack::Request


=begin markdown
The resource factory for the current request.
@return [#[]]
@see Server#initialize
@since 0.0.1
=end
  def resource_factory; self.env['rackful.resource_factory']; end
  def base_path
    self.env['rackful.base_path'] ||= begin
      r = self.content_path.dup
      r[%r{[^/]*\z}] = ''
      r
    end
  end
=begin markdown
Similar to the HTTP/1.1 `Content-Location:` header. Contains the canonical path
to the requested resource, which may differ from {#path}
@return [Path]
@since 0.1.0
=end
  def content_path; self.env['rackful.content_path'] ||= self.path; end
=begin markdown
Set by {Rackful::Server#call!}
@return [Path]
@since 0.1.0
=end
  def content_path= bp; self.env['rackful.content_path'] = bp.to_path; end
=begin markdown
@return [Path]
@since 0.1.0
=end
  def path; super.to_path; end


  def initialize resource_factory, *args
    super( *args )
    self.env['rackful.resource_factory'] = resource_factory
  end


=begin markdown
The request currently being processed in the current thread.

In a multi-threaded server, multiple requests can be handled at one time.
This method returns the request object, created (and registered) by
{Server#call!}
@return [Request]
@since 0.0.1
=end
  def self.current
    Thread.current[:rackful_request]
  end


=begin markdown
Assert all <tt>If-*</tt> request headers.
@return [void]
@raise [HTTP304NotModified, HTTP400BadRequest, HTTP404NotFound, HTTP412PreconditionFailed]
  with the following meanings:

  -   `304 Not Modified`
  -   `400 Bad Request` Couldn't parse one or more <tt>If-*</tt> headers, or a
      weak validator comparison was requested for methods other than `GET` or
      `HEAD`.
  -   `404 Not Found`
  -   `412 Precondition Failed`
@see http://tools.ietf.org/html/rfc2616#section-13.3.3 RFC2616, section 13.3.3
  for details about weak and strong validator comparison.
@todo Implement support for the `If-Range:` header.
@since 0.0.1
=end
  def assert_if_headers resource
    #raise HTTP501NotImplemented, 'If-Range: request header is not supported.' \
    #  if @env.key? 'HTTP_IF_RANGE'
    empty = resource.empty?
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
      :match => self.if_match,
      :none_match => self.if_none_match,
      :modified_since => self.if_modified_since,
      :unmodified_since => self.if_unmodified_since
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
      if cond[:none_match] && self.validate_etag( etag, cond[:none_match] )
        raise HTTP412PreconditionFailed, 'If-None-Match'
      elsif cond[:match] && ! self.validate_etag( etag, cond[:match] )
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


=begin markdown
Hash of acceptable media types and their qualities.

This method parses the HTTP/1.1 `Accept:` header. If no acceptable media
types are provided, an empty Hash is returned.
@return [Hash{media_type => quality}]
@since 0.0.1
=end
  def accept
    @env['rackful.accept'] ||= begin
      Hash[
        @env['HTTP_ACCEPT'].to_s.split(',').collect do
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


=begin markdown
@!method if_match()
Parses the HTTP/1.1 `If-Match:` header.
@return [nil, Array<String>]
@see http://tools.ietf.org/html/rfc2616#section-14.24 RFC2616, section 14.24
@see #if_none_match
@since 0.0.1
=end
  def if_match none = false
    header = @env["HTTP_IF_#{ none ? 'NONE_' : '' }MATCH"]
    return nil unless header
    envkey = "rackful.if_#{ none ? 'none_' : '' }match"
    if %r{\A\s*\*\s*\z} === header
      return [ '*' ]
    elsif %r{\A(\s*(W/)?"([^"\\]|\\.)*"\s*,)+\z}m === ( header + ',' )
      return header.scan( %r{(?:W/)?"(?:[^"\\]|\\.)*"}m )
    end
    raise HTTP400BadRequest, "Couldn't parse If-#{ none ? 'None-' : '' }Match: #{header}"
  end


=begin markdown
Parses the HTTP/1.1 `If-None-Match:` header.
@return [nil, Array<String>]
@see http://tools.ietf.org/html/rfc2616#section-14.26 RFC2616, section 14.26
@see #if_match
@since 0.0.1
=end
  def if_none_match
    self.if_match true
  end


=begin markdown
@!method if_modified_since()
@return [nil, Time]
@see http://tools.ietf.org/html/rfc2616#section-14.25 RFC2616, section 14.25
@see #if_unmodified_since
@since 0.0.1
=end
  def if_modified_since unmodified = false
    header = @env["HTTP_IF_#{ unmodified ? 'UN' : '' }MODIFIED_SINCE"]
    return nil unless header
    begin
      header = Time.httpdate( header )
    rescue ArgumentError
      raise HTTP400BadRequest, "Couldn't parse If-#{ unmodified ? 'Unmodified' : 'Modified' }-Since: #{header}"
    end
    header
  end


=begin markdown
@return [nil, Time]
@see http://tools.ietf.org/html/rfc2616#section-14.28 RFC2616, section 14.28
@see #if_modified_since
@since 0.0.1
=end
  def if_unmodified_since
    self.if_modified_since true
  end


=begin markdown
Does any of the tags in `etags` match `etag`?
@param etag [#to_s]
@param etags [#to_a]
@example
  etag = '"foo"'
  etags = [ 'W/"foo"', '"bar"' ]
  validate_etag etag, etags
  #> true
@return [Boolean]
@see http://tools.ietf.org/html/rfc2616#section-13.3.3 RFC2616 section 13.3.3
  for details about weak and strong validator comparison.
@since 0.0.1
=end
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


end # class Request

end # module Rackful
