# Required for parsing:
require 'rack'

# Required for running:


module Rackful

=begin markdown
Mixin for resources served by {Server}.

{Server} helps you implement ReSTful resource objects quickly in a couple
of ways.  
Classes that include this module may implement a method `content_types`
for content negotiation. This method must return a Hash of
`media-type => quality` pairs. 
@see Server, ResourceFactory
=end
module Resource


  include Rack::Utils


=begin
Normally, when a module is included, all the instance methods of the included
module become available as instance methods to the including module/class. But
class methods of the included module don't become available as class methods to
the including class.


=end
  def self.included(base)
    base.extend ClassMethods
  end


  module ClassMethods

=begin
Meta-programmer method.
@example Have your resource rendered in XML and JSON
  class MyResource
    add_serializer MyResource2XML
    add_serializer MyResource2JSON, 0.5
  end
@param serializer [Serializer]
@param quality [Float]
@return [self]
=end
    def add_serializer serializer, quality = 1.0
      quality = quality.to_f
      quality = 1.0 if quality > 1.0
      quality = 0.0 if quality < 0.0
      s = [serializer, quality]
      serializer::CONTENT_TYPES.each {
        |content_type|
        self.serializers[content_type.to_s] = s
      }
      self
    end


    def serializers
      # The single '@' on the following line is on purpose!
      @rackful_resource_serializers ||= {}
    end


    def all_serializers
      # The single '@' on the following line is on purpose!
      @rackful_resource_all_serializers ||=
        if self.superclass.respond_to?(:all_serializers)
          self.superclass.all_serializers.merge( self.serializers ) do
            |key, oldval, newval|
            newval[1] >= oldval[1] ? newval : oldval
          end
        else
          self.serializers
        end
    end


=begin
Meta-programmer method.
@example Have your resource accept XML and JSON in `PUT` requests
  class MyResource
    add_media_type 'text/xml', :PUT
    add_media_type 'application/json', :PUT
  end
@param [#to_s] media_type
@param [#to_sym] method
@return [self]
=end
    def add_media_type media_type, method = :PUT
      method = method.to_sym
      self.media_types[method] ||= []
      self.media_types[method] << media_type.to_s
      self
    end


=begin
@return [Hash(method => Array(media_types))]
=end
    def media_types
      @rackful_resource_media_types ||= {}
    end


=begin
@todo Documentation
=end
    def all_media_types
      @rackful_resource_all_media_types ||=
        if self.superclass.respond_to?(:all_media_types)
          self.superclass.all_media_types.merge( self.media_types ) do
            |key, oldval, newval|
            oldval + newval
          end
        else
          self.media_types
        end
    end


=begin markdown
The best media type for the response body, given the current HTTP request.
@param accept [Hash]
@param require_match [Boolean]
@return [String] content-type
@raise [HTTP406NotAcceptable] if `require_match` is `true` and no match was found.
=end
    def best_content_type accept, require_match = true
      if accept.empty?
        return self.all_serializers.values.sort_by(&:last).last[0]::CONTENT_TYPES[0]
      end
      matches = []
      accept.each_pair {
        |accept_media_type, accept_quality|
        self.all_serializers.each_pair {
          |content_type, v|
          quality = v[1]
          media_type = content_type.split(';').first.strip
          if File.fnmatch( accept_media_type, media_type )
            matches << [ content_type, accept_quality * quality ]
          end
        }
      }
      if matches.empty?
        if require_match
          raise( HTTP406NotAcceptable, self.all_serializers.keys() )
        else
          return self.all_serializers.values.sort_by(&:last).last[0]::CONTENT_TYPES[0]
        end
      end
      matches.sort_by(&:last).last[0]
    end


  end # module ClassMethods


=begin markdown
@return [Serializer]
=end
  def serializer content_type
    @rackful_resource_serializers ||= {}
    @rackful_resource_serializers[content_type] ||=
      self.class.all_serializers[content_type][0].new( self, content_type )
  end


=begin
@!method do_METHOD( Request, Rack::Response )
  HTTP/1.1 method handler.

  To handle certain HTTP/1.1 request methods, resources must implement methods
  called `do_<HTTP_METHOD>`.
  @example Handling `PATCH` requests
    def do_PATCH request, response
      response['Content-Type'] = 'text/plain'
      response.body = [ 'Hello world!' ]
    end
  @abstract
  @return [void]
  @raise [HTTPStatus, RuntimeError]
=end


=begin markdown
The path of this resource.
@return [Rackful::Path]
@see #initialize
=end
  def path; @rackful_resource_path; end


  def path= path
    @rackful_resource_path = Path.new(path)
  end


  def title
    ( '/' == self.path ) ?
      Request.current.host :
      File.basename(self.path).to_path.unescape
  end


  def requested?
    self.path.slashify == Request.current.path.slashify
  end


=begin markdown
Does this resource _exists_?

For example, a client can `PUT` to a URL that doesn't refer to a resource
yet. In that case, your {Server#resource_factory resource factory} can
produce an empty resource to to handle the `PUT` request. `HEAD` and `GET`
requests will still yield `404 Not Found`.

@return [Boolean] The default implementation returns `false`.
=end
  def empty?
    false
  end


=begin markdown

=end
  def to_rackful
    self
  end


=begin markdown
@!attribute [r] get_etag
  The ETag of this resource.

  If your classes implement this method, then an `ETag:` response
  header is generated automatically when appropriate. This allows clients to
  perform conditional requests, by sending an `If-Match:` or
  `If-None-Match:` request header. These conditions are then asserted
  for you automatically.

  Make sure your entity tag is a properly formatted string. In ABNF:

      entity-tag    = [ "W/" ] quoted-string
      quoted-string = ( <"> *(qdtext | quoted-pair ) <"> )
      qdtext        = <any TEXT except <">>
      quoted-pair   = "\" CHAR

  @abstract
  @return [String]
  @see http://tools.ietf.org/html/rfc2616#section-14.19 RFC2616 section 14.19
=end


=begin markdown
@!attribute [r] get_last_modified
  Last modification of this resource.

  If your classes implement this method, then a `Last-Modified:` response
  header is generated automatically when appropriate. This allows clients to
  perform conditional requests, by sending an `If-Modified-Since:` or
  `If-Unmodified-Since:` request header. These conditions are then asserted
  for you automatically.
  @abstract
  @return [Array<(Time, Boolean)>] The timestamp, and a flag indicating if the
    timestamp is a strong validator.
  @see http://tools.ietf.org/html/rfc2616#section-14.29 RFC2616 section 14.29
=end


=begin markdown
@!method destroy()
  @return [Hash, nil] an optional header hash.
=end


=begin markdown
List of all HTTP/1.1 methods implemented by this resource.

This works by inspecting all the {#do_METHOD} methods this object implements.
@return [Array<Symbol>]
@private
=end
  def http_methods
    r = []
    if self.empty?
      if self.class.all_media_types[:PUT]
        r << :PUT
      end
    else
      r.push( :OPTIONS, :HEAD, :GET )
      r << :DELETE if self.respond_to?( :destroy )
    end
    self.class.public_instance_methods.each do
      |instance_method|
      if /\Ado_([A-Z]+)\z/ === instance_method
        r << $1.to_sym
      end
    end
    r
  end


=begin markdown
Handles an OPTIONS request.

As a courtesy, this module implements a default handler for OPTIONS
requests. It creates an `Allow:` header, listing all implemented HTTP/1.1
methods for this resource. By default, an `HTTP/1.1 204 No Content` is
returned (without an entity body).

Feel free to override this method at will.
@return [void]
@raise [HTTP404NotFound] `404 Not Found` if this resource is empty.
=end
  def http_OPTIONS request, response
    raise HTTP404NotFound, path if self.empty?
    response.status = status_code :no_content
    response.header['Allow'] = self.http_methods.join ', '
  end


=begin markdown
Handles a HEAD request.

This default handler for HEAD requests calls {#http\_GET}, and
then strips off the response body.

Feel free to override this method at will.
@return [self]
=end
  def http_HEAD request, response
    self.http_GET request, response
    response['Content-Length'] =
      response.body.reduce(0) do
        |memo, s| memo + bytesize(s)
      end.to_s
    # Is this really necessary? Doesn't Rack automatically strip the response
    # body for HEAD requests?
    response.body = []
  end


=begin markdown
@private
@param [Rackful::Request] request
@param [Rack::Response] response
@return [void]
@raise [HTTP404NotFound, HTTP405MethodNotAllowed]
=end
  def http_GET request, response
    raise HTTP404NotFound, path if self.empty?
    # May throw HTTP406NotAcceptable:
    content_type = self.class.best_content_type( request.accept )
    response['Content-Type'] = content_type
    response.status = status_code( :ok )
    response.headers.merge! self.default_headers
    # May throw HTTP405MethodNotAllowed:
    serializer = self.serializer( content_type )
    if serializer.respond_to? :headers
      response.headers.merge!( serializer.headers )
    end
    response.body = serializer
  end


=begin markdown
Wrapper around {#do_METHOD #do_GET}
@private
@return [void]
@raise [HTTP404NotFound, HTTP405MethodNotAllowed]
=end
  def http_DELETE request, response
    raise HTTP404NotFound, path if self.empty?
    raise HTTP405MethodNotAllowed, self.http_methods unless self.respond_to?( :destroy )
    response.status = status_code( :no_content )
    if headers = self.destroy( request, response )
      response.headers.merge! headers
    end
  end


=begin markdown
@private
@return [void]
@raise [HTTP415UnsupportedMediaType, HTTP405MethodNotAllowed] if the resource doesn't implement the `PUT` method.
=end
  def http_PUT request, response
    raise HTTP405MethodNotAllowed, self.http_methods unless self.respond_to? :do_PUT
    unless self.class.media_types[:PUT] &&
           self.class.media_types[:PUT].include?( request.media_type )
      raise HTTP415UnsupportedMediaType, self.class.media_types[:PUT]
    end
    response.status = status_code( self.empty? ? :created : :no_content )
    self.do_PUT( request, response )
    response.headers.merge! self.default_headers
  end


=begin markdown
Wrapper around {#do_METHOD #do_PUT}
@private
@return [void]
@raise [HTTPStatus] `405 Method Not Allowed` if the resource doesn't implement the `PUT` method.
=end
  def http_method request, response
    method = request.request_method.to_sym
    if ! self.respond_to?( :"do_#{method}" )
      raise HTTP405MethodNotAllowed, self.http_methods
    end
    if  ( request.content_length ||
          'chunked' == request.env['HTTP_TRANSFER_ENCODING'] ) and
        ! self.class.media_types[method] ||
        ! self.class.media_types[method].include?( request.media_type )
      raise HTTP415UnsupportedMediaType, self.class.media_types[method]
    end
    self.send( :"do_#{method}", request, response )
  end


=begin markdown
Adds `ETag:` and `Last-Modified:` response headers.
=end
  def default_headers
    r = {}
    r['ETag'] = self.get_etag \
      if self.respond_to?( :get_etag )
    r['Last-Modified'] = self.get_last_modified[0].httpdate \
      if self.respond_to?( :get_last_modified )
    r
  end


end # module Resource


=begin unused
module Collection


  include Enumerable


  def self.included( modul )
    unless modul.kind_of? Resource
      raise "module #{self} included in #{modul}, which isn't a Rackful::Resource"
    end
  end
  
  
  def recurse?; false; end
  
  
  def each_pair
    self.each do
      |path|
      yield [ path, Request.current.resource_factory( path ) ]
    end
  end


end # module Collection
=end


end # module Rackful
