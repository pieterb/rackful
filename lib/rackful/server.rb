# Required for parsing:
#require 'forwardable' # Used to be for ResourceFactoryWrapper.

# Required for running:

module Rackful

=begin markdown
Rack compliant server class for implementing RESTful web services.
=end
class Server


=begin markdown
An object responding thread safely to method `#[]`.

A {Server} has no knowledge, and makes no presumptions, about your URI namespace.
It requires a _Resource Factory_ which produces {Resource Resources} given
a certain absolute path.

The Resource Factory you provide need only implement one method, with signature
`Resource #[]( String path )`.
This method will be called with a URI-encoded path string, and must return a
{Resource}, or `nil` if there's no resource at the given path.

For example, if a Rackful client
tries to access a resource with URI {http://example.com/your/resource http://example.com/some/resource},
then your Resource Factory can expect to be called like this:

    resource = resource_factory[ '/your/resource' ]

If there's no resource at the given path, but you'd still like to respond to
`POST` or `PUT` requests to this path, you must return an
{Resource#empty? empty resource}.
@return [#[]]
@see #initialize
=end
  attr_reader :resource_factory


=begin markdown
@param resource_factory [#[]] see Server#resource_factory
=end
  def initialize(resource_factory)
    super()
    @resource_factory = resource_factory
  end


=begin markdown
As required by the Rack specification.

For thread safety, this method clones `self`, which handles the request in
{#call!}. A similar approach is taken by the Sinatra library.
@return [Array<(status_code, response_headers, response_body)>]
=end
  def call(p_env)
    start = Time.now
    retval = dup.call! p_env
    #$stderr.puts( p_env.inspect )
    retval
  end


=begin markdown
@return [Array<(status_code, response_headers, response_body)>]
=end
  def call!(p_env)
    request = Request.new( self.resource_factory, p_env )
    # See also Request::current():
    Thread.current[:rackful_request] = request
    response = Rack::Response.new
    begin
      raise HTTP404NotFound, request.path \
        unless resource = self.resource_factory[Path.new(request.path)]
      unless resource.path == request.path
        response.header['Content-Location'] = resource.path
        request.content_path = resource.path
      end
      request.assert_if_headers resource
      if %w{HEAD GET OPTIONS PUT DELETE}.include?( request.request_method )
        resource.__send__( :"http_#{request.request_method}", request, response )
      else
        resource.http_method request, response
      end
    rescue HTTPStatus => e
      # Already handled by HTTPStatus#initialize:
      #raise if $DEBUG && 500 <= e.status
      bct = e.class.best_content_type request.accept, false
      serializer = e.serializer(bct)
      response = Rack::Response.new serializer, e.status, e.headers
    ensure
      # The next line fixes a small peculiarity in RFC2616: the response body of
      # a `HEAD` request _must_ be empty, even for responses outside 2xx.
      if request.head?
        response.body = []
      end
    end
    if  201 == response.status &&
        ( location = response['Location'] ) &&
        ( new_resource = request.resource_factory[location] ) &&
        ! new_resource.empty? \
    or  ( (200...300) === response.status ||
           304        ==  response.status ) &&
        ! response['Location'] &&
        ( new_resource = request.resource_factory[request.path] ) &&
        ! new_resource.empty?
      response.headers.merge! new_resource.default_headers
    end
    r = response.finish
    #~ $stderr.puts r.inspect
    r
  end


end # class Server


end # module Rackful
