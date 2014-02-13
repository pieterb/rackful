# encoding: utf-8
# Required for parsing:
require 'rackful/resource.rb'
require 'rackful/serializer.rb'


module Rackful

=begin markdown
Exception which represents an HTTP Status response.
@abstract
=end
class HTTPStatus < RuntimeError


  include Resource


  attr_reader :status, :headers, :to_rackful


=begin markdown
@param status [Symbol, Integer] e.g. `404` or `:not_found`
@param message [String] XHTML
@param info [ { Symbol => Object, String => String } ]
    *   {Object}s indexed by {Symbol}s are returned in the response body.
    *   {String}s indexed by {String}s are returned as response headers.
=end
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


  def title
    "#{status} #{Rack::Utils::HTTP_STATUS_CODES[status]}"
  end


  class XHTML < Serializer::XHTML


    def header
      super + <<EOS
<h1>HTTP/1.1 #{Rack::Utils.escape_html(resource.title)}</h1>
<div id="rackful-description">#{resource.message}</div>
EOS
    end


    def headers; self.resource.headers; end


  end # class XHTML


  add_serializer XHTML, 1.0


end # class Rackful::HTTPStatus


=begin markdown
@abstract Base class for HTTP status codes with only a simple text message, or
  no message at all.
=end
class HTTPSimpleStatus < HTTPStatus

  def initialize message = nil
    /HTTP(\d\d\d)\w+\z/ === self.class.to_s
    status = $1.to_i
    super( status, message )
  end

end


class HTTP201Created < HTTPStatus

  def initialize locations
    locations = [ locations ] unless locations.kind_of? Array
    locations = locations.collect { |l| URI(l) }
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

  def initialize location = nil
    if location
      location = URI(location)
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

  def initialize location
    location = URI(location)
    super( 301, '', :'New location:' => location, 'Location' => location )
  end

end


class HTTP303SeeOther < HTTPStatus

  def initialize location
    location = URI(location)
    super( 303, '', :'See:' => location, 'Location' => location )
  end

end


class HTTP304NotModified < HTTPStatus

  def initialize
    super( 304 )
  end

end


class HTTP307TemporaryRedirect < HTTPStatus

  def initialize location
    location = URI(location)
    super( 301, '', :'Current location:' => location, 'Location' => location )
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

end # module Rackful
