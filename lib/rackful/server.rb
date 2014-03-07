# encoding: utf-8

# Required for parsing:
require 'rackful/global.rb'

# Required for running:


module Rackful

# Rack compliant server class for implementing RESTful web services.
class Rackful::Server
  
  include StatusCodes


  # As required by the Rack specification.
  #
  # @param env [{String => Mixed}]
  # @return [(status_code, response_headers, response_body)]
  def call( env )
    request = Request.new( env )
    response = Rack::Response.new
    resource = request.resource
    if request.url != request.canonical_uri.to_s
      if %w{HEAD GET}.include?( request.request_method )
        raise HTTP404NotFound if resource.empty?
        raise HTTP301MovedPermanently, request.canonical_uri
      end
      response.header['Content-Location'] = request.canonical_uri.to_s
    end
    if %w{HEAD GET OPTIONS PATCH POST PUT DELETE}.include?( request.request_method )
      resource.__send__( :"http_#{request.request_method}", request, response )
    else
      resource.http_method request, response
    end
    response.finish
  end


end # class Rackful::Server

end # module Rackful
