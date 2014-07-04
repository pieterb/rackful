# encoding: utf-8

# Required for parsing:
require_relative 'global.rb'

# Required for running:


module Rackful

# Rack compliant server class for implementing RESTful web services.
#
# This class is explicitly *not* a singleton: there can be multiple instances
# of Rackful::Server, for example serving different parts of the URI namespace.
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
  # @yieldparam uri [URI] The {URI::Generic#normalize! normalized}
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
      if resource.empty? and %w{DELETE GET HEAD PATCH POST}.include?( request.request_method )
        raise HTTP404NotFound
      end
      if request.url != request.canonical_uri.to_s
        # Why did I think this was a good idea?:
        #if %w{HEAD GET}.include?( request.request_method )
        #  raise HTTP301MovedPermanently, request.canonical_uri
        #end
        response.header['Content-Location'] = request.canonical_uri.to_s
      end
      request.assert_if_headers
      if %w{HEAD GET OPTIONS PATCH POST PUT DELETE}.include?( request.request_method )
        resource.__send__( :"http_#{request.request_method}", request, response )
      else
        resource.http_OTHER request, response
      end
      # Make sure the Location: response header contains an absolute URI:
      if response['Location'] and response['Location'][0] == ?/
        response['Location'] = ( request.canonical_uri + response['Location'] ).to_s
      end
    rescue HTTPStatus
      response = $!.to_response(request)
    end
    begin
      if  201 == response.status &&
          ( location = response['Location'] ) &&
          ( new_resource = request.resource_at( location ) ) &&
          ! new_resource.empty? \
      or  ( (200...300) === response.status ) && # <-- || 304        ==  response.status ) &&
          ! response['Location'] &&
          ( new_resource = request.resource_at( request.canonical_uri ) ) &&
          ! new_resource.empty?
        response.headers.merge! new_resource.default_headers
      end
    rescue HTTP404NotFound
    end
    response.finish
  end


  private


  def relative_to_absolute_location request, response
    if response['Location'] and response['Location'][0] == ?/
      response['Location'] = ( request.canonical_uri + response['Location'] ).to_s
    end
  end



end # class Rackful::Server

end # module Rackful
