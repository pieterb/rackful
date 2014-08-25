# encoding: utf-8

# Required for parsing:
require_relative 'global.rb'

# Required for running:


module Rackful

  # Mixin for resources served by {Server}.
  #
  # This module includes module `StatusCodes` for convenience, as explained in the {StatusCodes StatusCodes documentation}.
  # @see Server
  # @abstract Realizations must implement {#do_METHOD #do_<METHOD>} for each supported method.
  #
  # @!method etag
  #   If your classes provide this method, then an `ETag:` response header is generated automatically when appropriate. This allows clients to perform conditional requests, by sending an `If-Match:` or `If-None-Match:` request header. These conditions are then asserted or you automatically.
  #
  #   Make sure your entity tag is a properly formatted string. In ABNF:
  #
  #   ```abnf
  #   entity-tag    = [ "W/" ] quoted-string
  #   quoted-string = ( <"> *(qdtext | quoted-pair ) <"> )
  #   qdtext        = <any TEXT except <">>
  #   quoted-pair   = "\" CHAR
  #   ```
  #
  #   @return [String] The ETag of this resource.
  #   @see http://tools.ietf.org/html/rfc2616#section-14.19 RFC2616 section 14.19
  #
  # @!method last_modified
  #   Set callback for `Last-Modified` info.
  #
  #   If your classes provide this callback, then a `Last-Modified:` response header is generated automatically when appropriate. This allows clients to perform conditional requests, by sending an `If-Modified-Since:` or `If-Unmodified-Since:` request header. These conditions are then asserted for you automatically.
  #   @return [Array<(Time, Boolean)>] The timestamp, and a flag indicating if the timestamp is a strong validator.
  #   @see http://tools.ietf.org/html/rfc2616#section-14.29 RFC2616 section 14.29
  module Resource

    include StatusCodes

    # @return [URI] The canonical path of this resource.
    attr_reader :uri

    def uri=( uri )
      @uri = uri.kind_of?(URI) ? uri.dup : URI(uri)
      @uri.normalize!
      uri
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


    def handles? method
      self.respond_to? "do_#{method}".to_sym
    end


    # List of all HTTP/1.1 methods implemented by this resource.
    #
    # This works by inspecting all the {#do_METHOD} methods this object implements.
    # @return [Array<Symbol>]
    # @api private
    def http_methods
      r = { :OPTIONS => true }
      self.class.public_instance_methods.each do
        |instance_method|
        if /\Ado_([A-Z]+)\z/ === instance_method
          r[$1.to_sym] = true
        end
      end
      if self.empty?
        [ :DELETE, :GET, :HEAD, :PATCH ].each do |method|
          r.delete(method)
        end
      end
      r.keys
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
    # @raise [HTTP404NotFound, HTTP405MethodNotAllowed]
    def http_GET request, response
      response.status = Rack::Utils.status_code( :ok )
      if respond_to? :do_GET
        do_GET(request, response)
      else
        raise(HTTP405MethodNotAllowed, self.http_methods)
      end
      response.headers.merge! self.default_headers
    end


    # Wrapper around {#do_METHOD #do_GET}
    # @api private
    # @raise [HTTP404NotFound, HTTP405MethodNotAllowed]
    def http_DELETE request, response
      raise HTTP405MethodNotAllowed, self.http_methods() unless
      self.respond_to?( :do_DELETE )
      response.status = Rack::Utils.status_code( :no_content )
      self.do_DELETE( request, response )
    end


    # @api private
    # @raise [HTTP404NotFound, HTTP415UnsupportedMediaType, HTTP405MethodNotAllowed] if the
    #   resource doesn’t implement the `PATCH` method or can’t handle the provided
    #   request body media type.
    def http_PATCH request, response
      if respond_to? :do_PATCH
        response.status = :no_content
        do_PATCH( request, response )
        response.headers.merge! self.default_headers
      else
        raise HTTP405MethodNotAllowed, http_methods()
      end
    end


    # @api private
    # @raise [HTTP415UnsupportedMediaType, HTTP405MethodNotAllowed] if the
    #   resource doesn’t implement the `POST` method or can’t handle the provided
    #   request body media type.
    def http_POST request, response
      if respond_to?( :do_POST )
        do_POST( request, response )
      else
        raise HTTP405MethodNotAllowed, http_methods()
      end
    end


    # @api private
    # @raise [HTTP415UnsupportedMediaType, HTTP405MethodNotAllowed] if the
    #   resource doesn’t implement the `PUT` method or can’t handle the provided
    #   request body media type.
    def http_PUT request, response
      unless request.content_length || 'chunked' == request.env['HTTP_TRANSFER_ENCODING']
        raise HTTP411LengthRequired
      end
      if respond_to? :do_PUT
        response.status = Rack::Utils.status_code( self.empty? ? :created : :no_content )
        self.do_PUT( request, response )
        response.headers.merge! self.default_headers
      else
        raise HTTP405MethodNotAllowed, http_methods()
      end
    end


    # Wrapper around {#do_METHOD}
    # @api private
    # @raise [HTTPStatus] `405 Method Not Allowed` if the resource doesn't implement
    #   the request method.
    def http_OTHER request, response
      method = request.request_method
      unless self.handles? method
        raise HTTP405MethodNotAllowed, self.http_methods
      end
      send( "do_#{method}".to_sym, request, response )
    end


    # Adds `ETag:` and `Last-Modified:` response headers.
    def default_headers
      r = {}
      r['ETag'] = self.etag if self.respond_to?( :etag )
      r['Last-Modified'] = self.last_modified[0].httpdate if self.respond_to?( :last_modified )
      r
    end


  end # module Rackful::Resource


end # module Rackful
