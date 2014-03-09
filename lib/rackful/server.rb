# encoding: utf-8

# Required for parsing:
require 'rackful/global.rb'

# Required for running:


module Rackful

# Rack compliant server class for implementing RESTful web services.
class Rackful::Server
  
  include StatusCodes


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
  # @yieldparam uri [URI::Generic] The {URI::Generic#normalize! normalized}
  #   URI of the requested resource.
  # @yieldreturn [Resource] A (possibly {Resource#empty? empty}) resource, or nil.
  def initialize &resource_registry
    @resource_registry = resource_registry
  end



  # As required by the Rack specification.
  #
  # @param env [{String => Mixed}]
  # @return [(status_code, response_headers, response_body)]
  def call( env )
    env['rackful.resource_registry'] ||= @resource_registry
    request = Request.new( env )
    response = Rack::Response.new
    begin
      resource = request.resource
      if request.url != request.canonical_uri.to_s
        if %w{HEAD GET}.include?( request.request_method )
          raise HTTP404NotFound if resource.empty?
          raise HTTP301MovedPermanently, request.canonical_uri
        end
        response.header['Content-Location'] = request.canonical_uri.to_s
       end
      request.assert_if_headers
      if %w{HEAD GET OPTIONS PATCH POST PUT DELETE}.include?( request.request_method )
        resource.__send__( :"http_#{request.request_method}", request, response )
      else
        resource.http_method request, response
      end
    rescue HTTPStatus => e
      serializer = e.serializer(request, false)
      response = Rack::Response.new
      response.status = e.status
      # Lint requires that status 304 (Not Modified) has no body and no
      # Content-Type response header.
      unless 304 === e.status
        response['Content-Type'] = serializer.content_type
        response.body = serializer
      end
      response.headers.merge!( serializer.headers ) if serializer.respond_to? :headers
    end
    # The next line fixes a small peculiarity in RFC2616: the response body of
    # a `HEAD` request _must_ be empty, even for responses outside 2xx.
    if request.head?
      response.body = []
     end
    begin
      if  201 == response.status &&
          ( location = response['Location'] ) &&
          ( new_resource = request.resource_at( location ) ) &&
          ! new_resource.empty? \
      or  ( (200...300) === response.status ||
             304        ==  response.status ) &&
          ! response['Location'] &&
          ( new_resource = request.resource_at( request.canonical_uri ) ) &&
          ! new_resource.empty?
        response.headers.merge! new_resource.default_headers
      end
      # Make sure the Location: response header contains an absolute URI:
      if  response['Location'] and response['Location'][0] == ?/
        response['Location'] = ( request.canonical_uri + response['Location'] ).to_s
      end
    rescue HTTP404NotFound => e
    end
    response.finish
  end


end # class Rackful::Server

end # module Rackful
