# Required for parsing:
require 'rackful/resource.rb'
require 'rackful/serializer.rb'

# Required for running
require 'rexml/rexml'


module Rackful

=begin markdown
Exception which represents an HTTP Status response.
@abstract
=end
class HTTPStatus < RuntimeError


  include Resource
  
  
  attr_reader :status, :headers, :to_rackful


=begin markdown
@param [Symbol, Integer] status e.g. `404` or `:not_found`
@param [String] message XHTML
@param [ { Symbol => Object }, { String => String } ] info
    *   If the Hash is indexed by {Symbol}s, then the values will be returned in
        the response body.
    *   If the Hash is indexed by {String}s, the +key => value+ pairs are returned
        as response headers.
=end
  def initialize status, message = nil, info = {}
    self.path = Request.current.path
    @status = status_code status
    raise "Wrong status: #{status}" if 0 === @status
    message ||= ''
    @headers = {}
    @to_rackful = {}
    info.each do
      |k, v|
      if k.kind_of? Symbol then @to_rackful[k] = v
      else @headers[k] = v end
    end
    @to_rackful = nil if @to_rackful.empty?
    begin
      REXML::Document.new \
        '<?xml version="1.0" encoding="UTF-8" ?>' +
        "<div>#{message}</div>"
    rescue
      message = Rack::Utils.escape_html(message)
    end
    super message
    if 500 <= @status
      errors = Request.current.env['rack.errors']
      errors.puts self.inspect
      errors.puts "Headers: #{@headers.inspect}"
      errors.puts "Info: #{@to_rackful.inspect}"
    end
  end
  
  
  def title
    "#{status} #{HTTP_STATUS_CODES[status]}"
  end


  class XHTML < ::Rackful::XHTML


    def header
      super + <<EOS
<h1>HTTP/1.1 #{Rack::Utils.escape_html(resource.title)}</h1>
<div id="rackful_description">#{resource.message}</div>
EOS
    end


    def headers; self.resource.headers; end
    
    
  end # class HTTPStatus::XHTML


  #~ class JSON < ::Rackful::JSON
#~ 
#~ 
    #~ def headers; self.resource.headers; end
#~ 
#~ 
    #~ def each &block
      #~ super( [ self.resource.message, self.resource.to_rackful ], &block )
    #~ end
#~ 
#~ 
  #~ end # class HTTPStatus::XHTML


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
    locations = locations.collect { |l| l.to_path }
    rf = Request.current.resource_factory
    if locations.size > 1
      locations = locations.collect {
        |l|
        resource = rf[l]
        { :location => l }.merge( resource.default_headers )
        rf.uncache l if rf.respond_to? :uncache
      }
      super(
        201, 'New resources were created:', :locations => locations
      )
    else
      location = locations[0]
      resource = rf[location]
      super(
        201, 'A new resource was created:', {
          :location => location,
          'Location' => location
        }.merge( resource.default_headers )
      )
    end
  end

end # class HTTP201Created


class HTTP202Accepted < HTTPStatus

  def initialize location = nil
    if location
      super(
        202, '', {
          :'Job status location:' => Path.new(locations),
          'Location' => locations
        }
      )
    else
      super 202
    end
  end

end # class HTTP202Accepted


class HTTP301MovedPermanently < HTTPStatus

  def initialize location
    super(
      301, '', {
        :'New location:' => Path.new(location),
        'Location' => location
      }
    )
  end

end


class HTTP303SeeOther < HTTPStatus

  def initialize location
    super(
      303, '', {
        :'See:' => Path.new(location),
        'Location' => location
      }
    )
  end

end


class HTTP304NotModified < HTTPStatus

  def initialize
    super( 304 )
  end

end


class HTTP307TemporaryRedirect < HTTPStatus

  def initialize location
    super(
      301, '', {
        :'Current location:' => Path.new(location),
        'Location' => location
      }
    )
  end

end


class HTTP400BadRequest < HTTPSimpleStatus; end

class HTTP403Forbidden < HTTPSimpleStatus; end

class HTTP404NotFound < HTTPSimpleStatus; end


class HTTP405MethodNotAllowed < HTTPStatus

  def initialize methods
    super 405, '', 'Allow' => methods.join(', '),
          :'Allowed methods:' => methods
  end

end


class HTTP406NotAcceptable < HTTPStatus

  def initialize content_types
    super 406, '',
          :'Available content-type(s):' => content_types
  end

end


class HTTP409Conflict < HTTPSimpleStatus; end

class HTTP410Gone < HTTPSimpleStatus; end

class HTTP411LengthRequired < HTTPSimpleStatus; end


class HTTP412PreconditionFailed < HTTPStatus

  def initialize header = nil
    info =
      if header
        { header.to_sym => Request.current.env[ 'HTTP_' + header.gsub('-', '_').upcase ] }
      else
        {}
      end
    super 412, 'Failed precondition:', info
  end

end


class HTTP415UnsupportedMediaType < HTTPStatus

  def initialize media_types
    super 415, '',
          :'Supported media-type(s):' => media_types
  end

end


class HTTP422UnprocessableEntity < HTTPSimpleStatus; end

class HTTP500InternalServerError < HTTPSimpleStatus; end

class HTTP501NotImplemented < HTTPSimpleStatus; end

class HTTP503ServiceUnavailable < HTTPSimpleStatus; end

end # module Rackful
