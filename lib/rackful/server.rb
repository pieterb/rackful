# encoding: utf-8


module Rackful

=begin markdown
Rack compliant server class for implementing RESTful web services.
=end
class Server


=begin markdown
@return [#resource]
@see #initialize
@see ResourceFactory
=end
  attr_reader :resource_factory


=begin markdown
@param resource_factory [#resource] The {ResourceFactory resource factory} to
  be used by this server.
=end
  def initialize(resource_factory)
    super()
    @resource_factory = resource_factory
  end


=begin markdown
As required by the Rack specification.

For thread safety, this method clones `self`, which handles the request in
{#call!}.
For reentrancy, the clone is stored in the environment.
@return [Array<(status_code, response_headers, response_body)>]
=end
  def call( p_env )
    ( p_env['rackful.server'] ||= self.dup ).call!( p_env )
  end


=begin markdown
@return [Array<(status_code, response_headers, response_body)>]
=end
  def call!( p_env )
    request = Request.new( self.resource_factory, p_env )
    response = Rack::Response.new
    begin
      unless resource = self.resource_factory[request.url]
        raise HTTP404NotFound, request.url
      end
      unless resource.url == request.url
        response.header['Content-Location'] = resource.url
        request.content_location = resource.url
      end
      request.assert_if_headers resource
      if %w{HEAD GET OPTIONS PUT DELETE}.include?( request.request_method )
        resource.__send__( :"http_#{request.request_method}", request, response )
      else
        resource.http_method request, response
      end
    rescue HTTPStatus => e
      e.url = request.content_location
      content_type = e.class.best_content_type( request.accept, false )
      response = Rack::Response.new
      response['Content-Type'] = content_type
      response.status = e.status
      serializer = e.serializer(request, content_type)
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
    if  201 == response.status &&
        ( location = response['Location'] ) &&
        ( new_resource = request.resource_factory[location] ) &&
        ! new_resource.empty? \
    or  ( (200...300) === response.status ||
           304        ==  response.status ) &&
        ! response['Location'] &&
        ( new_resource = request.resource_factory[request.url] ) &&
        ! new_resource.empty?
      response.headers.merge! new_resource.default_headers
    end
    response.finish
  end


end # class Server


end # module Rackful
