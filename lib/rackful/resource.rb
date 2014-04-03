# encoding: utf-8

# Required for parsing:
require 'rackful/global.rb'

# Required for running:

module Rackful

# Abstract superclass for resources served by {Server}.
#
# This class mixes in module `StatusCodes` for convenience, as explained in the
# {StatusCodes StatusCodes documentation}.
# @see Server
# @todo better documentation
# @abstract Realizations must implement…
#
# @!method do_METHOD( Request, Rack::Response )
#   HTTP/1.1 method handler.
# 
#   To handle certain HTTP/1.1 request methods, resources must implement methods
#   called `do_<HTTP_METHOD>`. The return value of these methods is irrelevant.
#   @example Handling `PATCH` requests
#     def do_PATCH request, response
#       response['Content-Type'] = 'text/plain'
#       response.body = [ 'Hello world!' ]
#     end
#   @abstract
#   @raise [HTTPStatus, RuntimeError]
#
# @!attribute [r] get_etag
#   The ETag of this resource.
# 
#   If your classes implement this method, then an `ETag:` response
#   header is generated automatically when appropriate. This allows clients to
#   perform conditional requests, by sending an `If-Match:` or
#   `If-None-Match:` request header. These conditions are then asserted
#   for you automatically.
# 
#   Make sure your entity tag is a properly formatted string. In ABNF:
# 
#       entity-tag    = [ "W/" ] quoted-string
#       quoted-string = ( <"> *(qdtext | quoted-pair ) <"> )
#       qdtext        = <any TEXT except <">>
#       quoted-pair   = "\" CHAR
# 
#   @abstract
#   @return [String]
#   @see http://tools.ietf.org/html/rfc2616#section-14.19 RFC2616 section 14.19
# 
# @!attribute [r] get_last_modified
#   Last modification of this resource.
# 
#   If your classes implement this method, then a `Last-Modified:` response
#   header is generated automatically when appropriate. This allows clients to
#   perform conditional requests, by sending an `If-Modified-Since:` or
#   `If-Unmodified-Since:` request header. These conditions are then asserted
#   for you automatically.
#   @abstract
#   @return [Array<(Time, Boolean)>] The timestamp, and a flag indicating if the
#     timestamp is a strong validator.
#   @see http://tools.ietf.org/html/rfc2616#section-14.29 RFC2616 section 14.29
# 
# @!method destroy()
#   @return [Hash, nil] an optional header hash.
module Resource
  
  include StatusCodes

  module ClassMethods


  # Meta-programmer method.
  # @example Have your resource rendered in XML and JSON
  #   class MyResource
  #     include Rackful::Resource
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
    sq = [serializer, quality]
    serializer.content_types.each do
      |content_type|
      unless  ( old = serializers[content_type] ) and # @formatter:off
              old[1] > quality # @formatter:on
        serializers[content_type] = sq
      end
    end
    self
  end


  # Meta-programmer method.
  #
  # A parser is an object or a class that implements to the following two methods:
  #
  # 1.  (Array<String>) media_types()
  # 2.  (void) parse(Request, Resource)
  #
  # The first call returns a list of media types this parser can parse, for example:
  # `[ 'text/html', 'application/xhtml+xml' ]`. The second call parses a request
  # in the context of a certain resource.
  # @example Have your resource accept XHTML in `PUT` requests
  #   class MyResource
  #     include Rackful::Resource
  #     add_parser Rackful::Parser::XHTML, :PUT
  #   end
  # @param parser [#parse, #media_types] an implementation (ie. subclass) of {Parser}
  # @param method [#to_sym] For example: `:PUT` or `:POST`
  # @return [self]
  def add_parser parser, method = :PUT
    method = method.to_sym
    parsers[method] ||= []
    parser.media_types.each do
      |mt|
      parsers[method] << [mt, parser]
    end
    parsers[method].uniq!
    self
  end


  # All parsers for this class, including parsers added to parent classes.
  # The result of this method is cached, which will interfere with code reloading.
  # @return [Hash{Symbol => Array<Class>}]
  # @api private
  def all_parsers
    # The single '@' on the following line is on purpose!
    @rackful_resource_all_parsers ||=
      if self.superclass.respond_to?(:all_parsers)
        self.superclass.all_parsers.merge( parsers ) do
          |key, oldval, newval|
          ( oldval + newval ).uniq
        end
      else
        parsers
      end
  end


  # All serializers for this class, including those added to parent classes.
  # The result of this method is cached, which will interfere with code reloading.
  # @return [Hash{ String( content_type ) => Array( Serializer, Float(quality) ) }]
  # @api private
  def all_serializers
    # The single '@' on the following line is on purpose!
    @rackful_resource_all_serializers ||=
      if self.superclass.respond_to?(:all_serializers)
        self.superclass.all_serializers.merge( serializers ) do
          |key, oldval, newval|
          newval[1] >= oldval[1] ? newval : oldval
        end
      else
        serializers
      end
  end

  private

  # All parsers added to _this_ class.  Ie. not including parsers added
  # to parent classes.
  # @return [Hash{Symbol => Array<Class>}] A hash of lists of {Parser} classes,
  #   indexed by HTTP method.
  # @api private
  def parsers
    # The single '@' on the following line is on purpose!
    @rackful_resource_parsers ||= {}
  end


  # All serializers added to _this_ class.  Ie. not including serializers added
  # to parent classes.
  # @return [Hash{ String( content_type ) => Array( Serializer, Float(quality) ) }]
  # @api private
  def serializers
    # The single '@' on the following line is on purpose!
    @rackful_resource_serializers ||= {}
  end


  end # module ClassMethods


  # This callback includes all methods of {ClassMethods} into all classes that
  # include {Resource}, to make them available as a tiny DSL.
  # @api private
  def self.included(base)
    base.extend ClassMethods
  end


  # Parse and “execute” the request body.
  # @param request [Rackful::Request]
  # @param response [Rack::Response]
  # @return [Parser, nil] a {Parser}, or nil if the request entity is empty
  # @raise [HTTP415UnsupportedMediaType] if no parser can be found for the request entity
  # @api private
  def parse request, response
    unless request.content_length ||
           'chunked' == request.env['HTTP_TRANSFER_ENCODING']
      raise HTTP411LengthRequired
    end
    supported_media_types = []
    all_parsers = self.class.all_parsers[ request.request_method.to_sym ] || []
    all_parsers.each do |mt, p|
      if File.fnmatch( mt, request_media_type, File::FNM_PATHNAME )
        return p.parse( request.media_type.to_s, response, self )
      end
      supported_media_types << mt
    end
    raise( HTTP415UnsupportedMediaType, supported_media_types.uniq )
  end


  # The canonical path of this resource.
  # @return [URI]
  attr_reader :uri


  def uri=( uri )
    @uri = uri.kind_of?(URI::Generic) ? uri.dup : URI(uri).normalize
  end


  def title
    self.uri.segments.last || self.class.to_s
  end


  # Does this resource _exist_?
  # 
  # For example, a client can `PUT` to a URL that doesn't refer to a resource
  # yet. In that case, your {Server#initialize resource registry} can
  # produce an empty resource to handle the `PUT` request. `HEAD` and `GET`
  # requests will still yield `404 Not Found`.
  # 
  # @return [Boolean] The default implementation returns `false`.
  def empty?
    false
  end

  # @todo documentation
  def to_rackful
    self
  end


  # List of all HTTP/1.1 methods implemented by this resource.
  # 
  # This works by inspecting all the {#do_METHOD} methods this object implements.
  # @return [Array<Symbol>]
  # @api private
  def http_methods
    r = [ :OPTIONS ]
    if self.empty?
      if self.class.all_media_types[:PUT]
        r << :PUT
      end
    else
      unless self.class.all_serializers.empty?
        r.push( :GET, :HEAD )
      end
      r << :DELETE if self.respond_to?( :destroy )
    end
    self.class.public_instance_methods.each do
      |instance_method|
      if /\Ado_([A-Z]+)\z/ === instance_method
        r << $1.to_sym
      end
    end
    r.uniq
  end


  # Handles an OPTIONS request.
  # 
  # As a courtesy, this module implements a default handler for OPTIONS
  # requests. It creates an `Allow:` header, listing all implemented HTTP/1.1
  # methods for this resource. By default, an `HTTP/1.1 204 No Content` is
  # returned (without an entity body).
  # 
  # Feel free to override this method at will.
  # @raise [HTTP404NotFound] `404 Not Found` if this resource is empty.
  def http_OPTIONS request, response
    response.status = Rack::Utils.status_code :no_content
    response.header['Allow'] = self.http_methods.join ', '
  end


  # Handles a HEAD request.
  # 
  # This default handler for HEAD requests calls {#http\_GET}, and
  # then strips off the response body.
  # 
  # Feel free to override this method at will.
  def http_HEAD request, response
    self.http_GET request, response
    response['Content-Length'] = '0'
    #    response['Content-Length'] ||=
    #      response.body.reduce(0) do
    #        |memo, s| memo + s.bytesize
    #      end.to_s
    # Strip the response body for HEAD requests?
    response.body = []
  end


  # @api private
  # @param request [Rackful::Request]
  # @param response [Rack::Response]
  # @raise [HTTP404NotFound, HTTP405MethodNotAllowed, HTTP406NotAcceptable]
  def http_GET request, response
    raise HTTP404NotFound if self.empty?
    response.status = Rack::Utils.status_code( :ok )
    if respond_to? :do_GET
      do_GET(request, response)
    elsif ! self.class.all_serializers.empty?
      # May throw HTTP406NotAcceptable:
      serializer = self.serializer( request )
      response['Content-Type'] = serializer.content_type
      if serializer.respond_to? :headers
        response.headers.merge!( serializer.headers )
      end
      response.body = serializer
    else
      raise(HTTP405MethodNotAllowed, self.http_methods)
    end
    response.headers.merge! self.default_headers
  end


  # The best serializer to represent this resource, given the current HTTP request.
  # @param request [Request] the current request
  # @param require_match [Boolean] this flag determines what must happen if the
  #   client sent an `Accept:` header, and we cannot serve any of the acceptable
  #   media types. **`TRUE`** means that an {HTTP406NotAcceptable} exception is
  #   raised. **`FALSE`** means that the content-type with the highest quality is
  #   returned.
  # @return [Serializer]
  # @raise [HTTP406NotAcceptable]
  def serializer( request, require_match = true )
    q_values = request.q_values # Array<Array(type, quality)>
    default_serializer = # @formatter:off
      # Hash{ String( content_type ) => Array( Serializer, Float(quality) ) }
      self.class.all_serializers.
      # Array< Array( Serializer, Float(quality) ) >
      values.sort_by(&:last).
      # Serializer
      last.first # @formatter:on
    best_match = [ default_serializer, 0.0, default_serializer.content_types.first ]
    q_values.each do
      |accept_media_type, accept_quality|
      self.class.all_serializers.each_pair do
        |content_type, sq|
        media_type = content_type.split(/\s*;\s*/).first
        if File.fnmatch( accept_media_type, media_type, File::FNM_PATHNAME ) and
           best_match.nil? || best_match[1] < ( accept_quality * sq[1] )
          best_match = [ sq[0], sq[1], content_type ]
        end
      end
    end
    if require_match and best_match[1] <= 0.0
      raise( HTTP406NotAcceptable, self.class.all_serializers.keys() )
    end
    best_match[0].new(request, self, best_match[2])
  end


  # Wrapper around {#do_METHOD #do_GET}
  # @api private
  # @raise [HTTP404NotFound, HTTP405MethodNotAllowed]
  def http_DELETE request, response
    raise HTTP404NotFound if self.empty?
    raise HTTP405MethodNotAllowed, self.http_methods unless
      self.respond_to?( :destroy )
    response.status = Rack::Utils.status_code( :no_content )
    if headers = self.destroy( request, response )
      response.headers.merge! headers
    end
  end


  # @api private
  # @raise [HTTP404NotFound, HTTP415UnsupportedMediaType, HTTP405MethodNotAllowed] if the
  #   resource doesn’t implement the `PATCH` method or can’t handle the provided
  #   request body media type.
  def http_PATCH request, response
    raise HTTP404NotFound if self.empty?
    response.status = :no_content
    if  self.respond_to? :do_PATCH
      self.do_PATCH( request, response )
    else
      parse(request, response)
    end
    response.headers.merge! self.default_headers
  end


  # @api private
  # @raise [HTTP415UnsupportedMediaType, HTTP405MethodNotAllowed] if the
  #   resource doesn’t implement the `POST` method or can’t handle the provided
  #   request body media type.
  def http_POST request, response
    if self.respond_to? :do_POST
      self.do_POST( request, response )
    else
      parse(request, response)
    end
  end


  # @api private
  # @raise [HTTP415UnsupportedMediaType, HTTP405MethodNotAllowed] if the
  #   resource doesn’t implement the `PUT` method or can’t handle the provided
  #   request body media type.
  def http_PUT request, response
    response.status = Rack::Utils.status_code( self.empty? ? :created : :no_content )
    if  self.respond_to? :do_PUT
      self.do_PUT( request, response )
    else
      parse(request, response)
    end
    response.headers.merge! self.default_headers
  end


  # Wrapper around {#do_METHOD}
  # @api private
  # @raise [HTTPStatus] `405 Method Not Allowed` if the resource doesn't implement
  #   the request method.
  def http_method request, response
    method = request.request_method.to_sym
    if ! self.respond_to?( :"do_#{method}" )
      raise HTTP405MethodNotAllowed, self.http_methods
    end
    self.send( :"do_#{method}", request, response )
  end


  # Adds `ETag:` and `Last-Modified:` response headers.
  def default_headers
    r = {}
    r['ETag'] = self.get_etag \
      if self.respond_to?( :get_etag )
    r['Last-Modified'] = self.get_last_modified[0].httpdate \
      if self.respond_to?( :get_last_modified )
    r
  end


end # module Rackful::Resource
end # module Rackful
