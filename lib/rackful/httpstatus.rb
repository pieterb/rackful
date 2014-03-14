# encoding: utf-8

# Required for parsing:
require 'rackful/global.rb'
require 'rackful/resource.rb'
require 'rackful/serializer.rb'

# Required for running:

module Rackful

# Groups together class {HTTPStatus} and its many subclasses into one namespace.
#
# For code brevity and legibility, this module is included in {Rackful},
# {Resource}, {Serializer}, and {Parser}. So class
# {HTTP404NotFound Rackful::StatusCodes::HTTP404NotFound}
# can also be addressed as {HTTP404NotFound} in any of those contexts.
module StatusCodes

  # Exception which represents an HTTP Status response.
  # @abstract
class HTTPStatus < RuntimeError

  include Resource
  
  class XHTML < Serializer::XHTML


    def header
      retval = super
      retval += "<h1>HTTP/1.1 #{Rack::Utils.escape_html(resource.title)}</h1>\n"
      unless resource.message.empty?
        retval += "<div id=\"rackful-description\">#{resource.message}</div>\n"
      end
      retval
    end


    def headers; self.resource.headers; end


  end # class Rackful::StatusCodes::HTTPStatus::XHTML


  add_serializer XHTML, 1.0
  add_serializer Serializer::JSON, 0.5

  attr_reader :status, :headers, :to_rackful


  # @param status [Symbol, Integer] e.g. `404` or `:not_found`
  # @param message [String] XHTML
  # @param info [ { Symbol => Object, String => String } ]
  #     *   **Objects** indexed by **Symbols** are returned in the response body.
  #     *   **Strings** indexed by **Strings** are returned as response headers.
  def initialize status, message = nil, info = {}
    @status = Rack::Utils.status_code status
    raise "Wrong status: #{status}" if 0 === @status
    message ||= ''
    @headers = {}
    @to_rackful = {}
    info.each do
      |k, v|
      if k.kind_of? Symbol
        @to_rackful[k] = v
      else
        @headers[k] = v.to_s
      end
    end
    @to_rackful = nil if @to_rackful.empty?
    if message
      message = message.to_s
      begin
        Nokogiri.XML(
          '<?xml version="1.0" encoding="UTF-8" ?>' +
          "<div>#{message}</div>"
        ) do |config| config.strict.nonet end
      rescue
        message = Rack::Utils.escape_html(message)
      end
    end
    super message
  end


  # @api private
  def title
    "#{status} #{Rack::Utils::HTTP_STATUS_CODES[status]}"
  end


  # @param request [Rackful::Request]
  # @return [Rack::Response]
  def to_response request
    response = Rack::Response.new
    response.status = self.status
    # Lint requires that status 304 (Not Modified) has no body and no
    # Content-Type response header.
    unless 304 === self.status
      serializer = self.serializer(request, false)
      response['Content-Type'] = serializer.content_type
      response.body = serializer
      if serializer.respond_to? :headers
        response.headers.merge!( serializer.headers )
      end
      # Make sure the Location: response header contains an absolute URI:
      if response['Location'] and response['Location'][0] == ?/
        response['Location'] = ( self.canonical_uri + response['Location'] ).to_s
      end
    end
    # The next line fixes a small peculiarity in RFC2616: the response body of
    # a `HEAD` request _must_ be empty, even for responses outside 2xx.
    if request.head?
      response.body = []
      response['Content-Length'] = 0
    end
    response
  end


end # class Rackful::StatusCodes::HTTPStatus


  # @abstract Base class for HTTP status codes with only a simple text message, or
  #   no message at all.
class HTTPSimpleStatus < HTTPStatus

  def initialize message = nil
    /HTTP(\d\d\d)\w+\z/ === self.class.to_s
    status = $1.to_i
    super( status, message )
  end

end


class HTTP201Created < HTTPStatus

  # @param locations [URI::Generic, String, Array<URI::Generic, String>]
  def initialize locations
    locations = [ locations ] unless locations.kind_of? Array
    locations = locations.collect do |location|
      location.kind_of?( URI::Generic ) ? location : URI(location).normalize
    end
    if locations.size > 1
      super( 201, 'New resources were created:', :locations => locations )
    else
      location = locations[0]
      super(
        201, 'A new resource was created:',
        :"Location" => location, 'Location' => location
      )
    end
  end

end


class HTTP202Accepted < HTTPStatus

  # @param location [URI::Generic, String]
  def initialize location = nil
    if location
      location = location.kind_of?( URI::Generic ) ? location : URI(location).normalize
      super(
        202, "The request body you sent has been accepted for processing.",
        :"Job status location:" => location, 'Location' => location
      )
    else
      super 202
    end
  end

end


class HTTP301MovedPermanently < HTTPStatus

  # @param location [URI::Generic, String]
  def initialize location
    location = location.kind_of?( URI::Generic ) ? location : URI(location).normalize
    super( 301, '', :'New location:' => location, 'Location' => location )
  end

end


class HTTP303SeeOther < HTTPStatus

  # @param location [URI::Generic, String]
  def initialize location
    location = location.kind_of?( URI::Generic ) ? location : URI(location).normalize
    super( 303, '', :'See:' => location, 'Location' => location )
  end

end


class HTTP304NotModified < HTTPStatus

  def initialize
    super( 304 )
  end

end


class HTTP307TemporaryRedirect < HTTPStatus

  # @param location [URI::Generic, String]
  def initialize location
    location = location.kind_of?( URI::Generic ) ? location : URI(location).normalize
    super( 307, '', :'Current location:' => location, 'Location' => location )
  end

end


class HTTP400BadRequest < HTTPSimpleStatus; end

class HTTP403Forbidden < HTTPSimpleStatus; end

class HTTP404NotFound < HTTPSimpleStatus; end


class HTTP405MethodNotAllowed < HTTPStatus

  def initialize methods
    super( 405, '', 'Allow' => methods.join(', '), :'Allowed methods:' => methods )
  end

end


class HTTP406NotAcceptable < HTTPStatus

  def initialize content_types
    super( 406, '', :'Available content-type(s):' => content_types )
  end

end


class HTTP409Conflict < HTTPSimpleStatus; end

class HTTP410Gone < HTTPSimpleStatus; end

class HTTP411LengthRequired < HTTPSimpleStatus; end


class HTTP412PreconditionFailed < HTTPStatus

  def initialize header = nil
    info = header ? { :'Failed precondition:' => header } : {}
    super( 412, '', info )
  end

end


class HTTP415UnsupportedMediaType < HTTPStatus

  def initialize media_types
    super( 415, '', :'Supported media-type(s):' => media_types )
  end

end


class HTTP422UnprocessableEntity < HTTPSimpleStatus; end

class HTTP501NotImplemented < HTTPSimpleStatus; end

class HTTP503ServiceUnavailable < HTTPSimpleStatus; end

end # module Rackful::StatusCodes
end # module Rackful
