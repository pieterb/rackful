# encoding: utf-8
module Rackful

# Abstract superclass for resources served by {Server}.
# @see Server
# @todo better documentation
# @abstract Realizations must implement…
module Resource



  def initialize( uri = nil )
    self.uri = uri
  end


  # This callback includes all methods of {ClassMethods} into all subclasses of
  # {Resource}, to make them available as a tiny DSL.
  # @api private
  def self.included(base)
    base.extend ClassMethods
  end


  # @see Resource::included
  module ClassMethods


  # Meta-programmer method.
  # @example Have your resource rendered in XML and JSON
  #   class MyResource
  #     add_serializer MyResource2XML
  #     add_serializer MyResource2JSON, 0.5
  #   end
  # @param serializer [Serializer]
  # @param quality [Float]
  # @return [self]
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


  # Meta-programmer method.
  # @example Have your resource accept XHTML in `PUT` requests
  #   class MyResource
  #     include Rackful::Resource
  #     add_parser Rackful::Parser::XHTML, :PUT
  #   end
  # @param parser [Class] an implementation (ie. subclass) of {Parser}
  # @param method [#to_sym] For example: `:PUT` or `:POST`
  # @return [self]
  def add_parser parser, method = :PUT
    method = method.to_sym
    self.parsers[method] ||= []
    self.parsers[method] << parser
    self.parsers[method].uniq!
    self
  end


  # All parsers added to _this_ class.  Ie. not including parsers added
  # to parent classes.
  # @return [Hash{Symbol => Array<Class>}] A hash of lists of {Parser} classes,
  #   indexed by HTTP method.
  # @api private
  def parsers
    @rackful_resource_parsers ||= {}
  end


  # All serializers added to _this_ class.  Ie. not including serializers added
  # to parent classes.
  # @return [Hash{Serializer => Float}]
  # @api private
  def serializers
    # The single '@' on the following line is on purpose!
    @rackful_resource_serializers ||= {}
  end


  # All parsers for this class, including parsers added to parent classes.
  # The result of this method is cached, which will interfere with code reloading.
  # @param method [#to_sym] For example: `:PUT` or `:POST`
  # @return [Hash{Symbol => Array<Class>}]
  # @api private
  def all_parsers
    # The single '@' on the following line is on purpose!
    @rackful_resource_all_parsers ||=
      if self.superclass.respond_to?(:all_parsers)
        self.parsers.merge( self.superclass.all_parsers ) do
          |key, oldval, newval|
          ( oldval + newval ).uniq
        end
      else
        self.parsers
      end
  end


  # All serializers for this class, including those added to parent classes.
  # The result of this method is cached, which will interfere with code reloading.
  # @return [Hash{Serializer => Float}] The float indicates the quality of each
  #   serializer in the interval [0,1]
  # @api private
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


  end # module ClassMethods


=begin markdown
@param request [Request]
@param content_type [String]
@return [Serializer]
=end
  def serializer request, content_type
    self.class.all_serializers[content_type][0].new( request, self, content_type )
  end


=begin markdown
The best media type for the response body, given the current HTTP request.
@param request [Rackful::Request]
@return [Parser, nil] a {Parser}, or nil if the request entity is empty
@raise [HTTP415UnsupportedMediaType] if no parser can be found for the request entity
=end
  def parser request
    unless request.content_length ||
           'chunked' == request.env['HTTP_TRANSFER_ENCODING']
      raise HTTP411LengthRequired
    end
    request_media_type = request.media_type.to_s
    supported_media_types = []
    all_parsers = self.class.all_parsers[ request.request_method.to_sym ] || []
    all_parsers.each do |p|
      p::MEDIA_TYPES.each do |parser_media_type|
        if File.fnmatch( parser_media_type, request_media_type )
          return p.new( request, self )
        end
        supported_media_types << parser_media_type
      end
    end
    raise( HTTP415UnsupportedMediaType, supported_media_types.uniq )
  end


=begin markdown
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
The canonical path of this resource.
@return [URI]
=end
  attr_reader :uri


=begin markdown
@param uri [String, URI]
=end
  def uri= uri
    @uri = uri.kind_of?( URI::Generic ) ? uri : URI(uri.to_s).normalize
    uri
  end


  def title
    self.uri.segments.last || self.class.to_s
  end


=begin markdown
Does this resource _exist_?

For example, a client can `PUT` to a URL that doesn't refer to a resource
yet. In that case, your {Server#initialize resource registry} can
produce an empty resource to handle the `PUT` request. `HEAD` and `GET`
requests will still yield `404 Not Found`.

@return [Boolean] The default implementation returns `false`.
=end
  def empty?
    false
  end

  # @todo documentation
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
@api private
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
    response.status = Rack::Utils.status_code :no_content
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
@api private
@param request [Rackful::Request]
@param response [Rack::Response]
@return [void]
@raise [HTTP404NotFound, HTTP405MethodNotAllowed]
=end
  def http_GET request, response
    raise HTTP404NotFound if self.empty?
    # May throw HTTP406NotAcceptable:
    content_type = request.best_content_type( self )
    response['Content-Type'] = content_type
    response.status = Rack::Utils.status_code( :ok )
    response.headers.merge! self.default_headers
    # May throw HTTP405MethodNotAllowed:
    serializer = self.serializer( request, content_type )
    if serializer.respond_to? :headers
      response.headers.merge!( serializer.headers )
    end
    response.body = serializer
  end


=begin markdown
Wrapper around {#do_METHOD #do_GET}
@api private
@return [void]
@raise [HTTP404NotFound, HTTP405MethodNotAllowed]
=end
  def http_DELETE request, response
    raise HTTP404NotFound if self.empty?
    raise HTTP405MethodNotAllowed, self.http_methods unless
      self.respond_to?( :destroy )
    response.status = Rack::Utils.status_code( :no_content )
    if headers = self.destroy( request, response )
      response.headers.merge! headers
    end
  end


=begin markdown
@api private
@return [void]
@raise [HTTP415UnsupportedMediaType, HTTP405MethodNotAllowed] if the resource doesn't implement the `PUT` method.
=end
  def http_PUT request, response
    raise HTTP405MethodNotAllowed, self.http_methods unless self.respond_to? :do_PUT
    response.status = Rack::Utils.status_code( self.empty? ? :created : :no_content )
    self.do_PUT( request, response )
    response.headers.merge! self.default_headers
  end


=begin markdown
Wrapper around {#do_METHOD}
@api private
@return [void]
@raise [HTTPStatus] `405 Method Not Allowed` if the resource doesn't implement
  the request method.
=end
  def http_method request, response
    method = request.request_method.to_sym
    if ! self.respond_to?( :"do_#{method}" )
      raise HTTP405MethodNotAllowed, self.http_methods
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


end # module Rackful
