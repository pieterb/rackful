# encoding: utf-8

# Required for parsing:
require 'rackful/global.rb'

# Required for running:

module Rackful

# Required middleware.
#
# This Rack middleware class must be included in the middleware stack *before*
# any of the other Rackful middlewares ({Conditional}, {HeaderSpoofing} and/or
# {MethodOverride}) and before the Rackful::Server app. It handles all exceptions
# thrown by these classes, and makes sure your resource provider (see 
# Required#initialize) is available higher up the stack.
class Required
  
  include StatusCodes

  # Constructor.
  #
  # Rackful has no knowledge, and makes no presumptions,
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
  def initialize app, &resource_registry
    @resource_registry = resource_registry
    @app = app
  end

  def call env
    env['rackful.resource_registry'] ||= @resource_registry
    request = Request.new( env )
    begin
      retval = @app.call env
    rescue StatusCodes::HTTPStatus => e
      # According to Lint, a status 304 shouldn’t be accompanied by a
      # Content-Type header or body:
      if 304 === e.status
        retval = [ e.status, {}, [] ]
      else
        retval = [ e.status, {}, e.serializer(request, false) ]
        retval[1]['Content-Type'] = retval[2].content_type
        retval[1].merge!( retval[2].headers ) if retval[2].respond_to? :headers
      end
    end
    # The next line fixes a small peculiarity in RFC2616: the response body of
    # a `HEAD` request _must_ be empty, even for responses outside 2xx.
    if request.head?
      retval[2] = []
    end
    begin
      if  201 === retval[0] &&
          ( location = retval[1]['Location'] ) &&
          ( new_resource = request.resource_at( location ) ) &&
          ! new_resource.empty? \
      or  ( (200...300) === retval[0] ||
             304        === retval[0] ) &&
          ! retval[1]['Location'] &&
          ( new_resource = request.resource_at( request.canonical_uri ) ) &&
          ! new_resource.empty?
        retval[1].merge! new_resource.default_headers
      end
      # Make sure the Location: response header contains an absolute URI:
      if retval[1]['Location'] and retval[1]['Location'][0] == ?/
        retval[1]['Location'] = ( request.canonical_uri + retval[1]['Location'] ).to_s
      end
    rescue StatusCodes::HTTP404NotFound => e
    end
    retval
  end

end
end