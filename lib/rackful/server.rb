module Rackful

# Rack compliant server class for implementing RESTful web services.
class Server


  # Constructor.
  #
  # This generic server class has no knowledge, and makes no presumptions,
  # about your URI namespace. It depends on the code block you provide here
  # to produce the {Resource} object which lives at a certain URI.
  # This block will be called with a {URI::Generic#normalize! normalized}
  # URI, and must return a {Resource}, or `nil` if there’s no
  # resource at the given URI.
  #
  # If there’s no resource at the given URI, but you’d still like to respond to
  # `POST` or `PUT` requests to this URI, you can return an
  # {Resource#empty? empty resource}.
  #
  # The provided code block must be thread-safe and reentrant.
  # @yieldparam uri [URI::Generic] The {URI::Generic::normalize! normalized}
  #   URI of the requested resource.
  # @yieldreturn [Resource] A (possibly {Resource#empty? empty}) resource, or nil.
  def initialize( &resource_registry )
    @resource_registry = resource_registry
  end


  # Calls the code block passed to the {#initialize constructor}.
  # @param uri [URI::HTTP, String]
  # @return [Resource]
  # @raise [HTTP404NotFound]
  def resource_at(uri)
    uri = URI(uri) unless uri.kind_of?( URI::Generic )
    retval = @resource_registry.call( uri.normalize )
    raise HTTP404NotFound unless retval
    retval
  end


  # As required by the Rack specification.
  #
  # For thread safety, this method clones `self`, which handles the request in
  # {#call!}.
  # For reentrancy, the clone is stored in the environment.
  # @param env [{String => Mixed}]
  # @return [(status_code, response_headers, response_body)]
  def call( env )
    ( env['rackful.server'] ||= self.dup ).call!( env )
  end


  # @see #call
  # @return [(status_code, response_headers, response_body)]
  def call!( env )
    request = Request.new( env )
    response = Rack::Response.new
    begin
      resource = resource_at( request.url )
      request.canonical_uri = resource.uri
      if request.url != request.canonical_uri.to_s
        if %w{HEAD GET}.include?( request.request_method )
          raise HTTP301MovedPermanently, request.canonical_uri
        end
        response.header['Content-Location'] = request.canonical_uri.to_s
      end
      request.assert_if_headers resource
      if %w{HEAD GET OPTIONS PUT DELETE}.include?( request.request_method )
        resource.__send__( :"http_#{request.request_method}", request, response )
      else
        resource.http_method request, response
      end
    rescue HTTPStatus => e
      serializer = e.serializer(request)
      response = Rack::Response.new
      response['Content-Type'] = serializer.content_type
      response.status = e.status
      if serializer.respond_to? :headers
        response.headers.merge!( serializer.headers )
      end
      response.body = serializer
    end
    # The next line fixes a small peculiarity in RFC2616: the response body of
    # a `HEAD` request _must_ be empty, even for responses outside 2xx.
    if request.head?
      response.body = []
    end
    begin
      if  201 == response.status &&
          ( location = response['Location'] ) &&
          ( new_resource = resource_at( location ) ) &&
          ! new_resource.empty? \
      or  ( (200...300) === response.status ||
             304        ==  response.status ) &&
          ! response['Location'] &&
          ( new_resource = resource_at( request.canonical_uri ) ) &&
          ! new_resource.empty?
        response.headers.merge! new_resource.default_headers
      end
    rescue HTTP404NotFound => e
    end
    response.finish
  end


end # class Server


end # module Rackful
