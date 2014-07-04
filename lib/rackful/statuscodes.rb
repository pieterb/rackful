# encoding: utf-8

# Required for parsing:
require_relative 'global.rb'
require_relative 'representation/hal_json.rb'

# Required for running:


module Rackful

  # Groups together class {HTTPStatus} and its many subclasses into one namespace.
  #
  # For code brevity and legibility, this module is included in {Resource}, {Serializer}, and {Parser}. So class {HTTP404NotFound Rackful::StatusCodes::HTTP404NotFound} can also be addressed as {HTTP404NotFound} in any of those contexts.
  module StatusCodes

    # Exception which represents an HTTP Status response.
    #
    # @!attribute [r] status
    #   @return [Integer]
    #
    # @!attribute [r] headers
    #   @return [Hash{String => String}]
    #

    class HTTPStatus < RuntimeError

      include Representable

      #      class XHTML5 < Serializer::XHTML5
      #
      #        def header
      #          retval = super
      #          retval += "<h1>HTTP/1.1 #{ resource.full_status }</h1>\n"
      #          unless resource.message.empty?
      #            retval += "<div id=\"rackful-description\">#{resource.message}</div>\n"
      #          end
      #          retval
      #        end
      #
      #
      #        def headers; resource.headers; end
      #
      #
      #      end # class Rackful::StatusCodes::HTTPStatus::XHTML5

      # @see #headers
      class HALJSON < Serializer::HALJSON

        # Just a proxy for `obj.resource.headers`.
        # @return [Hash{String => String}]
        def headers; resource.headers; end
      end


      add_serializer HALJSON

      attr_reader :status, :headers, :hal_links, :hal_properties


      # @return [String] The full HTTP status string, e.g. `"404 Not Found"`.
      def full_status
        @full_status ||= '%d %s' % [
          status, Rack::Utils::HTTP_STATUS_CODES[status]
        ]
      end


      # @param status [Symbol, Integer] e.g. `404` or `:not_found`
      # @param message [String] XHTML5
      # @param info [ { Symbol, String => Object, String } ]
      #   *   **Objects** indexed by **Symbols** are returned as HAL properties in the response body.
      #   *   **Strings** indexed by **Strings** are returned as response headers.
      def initialize status, message = nil, info = {}

        @status = Rack::Utils.status_code status
        raise "Wrong status: #{status}" if 0 === @status

        # Rack::Utils.escape_path just does true uri-escaping:
        # Commented out because resources no longer MUST have a uri.
        #self.uri = '/http_status/' + Rack::Utils.escape_path( self.full_status )

        @hal_properties = {
          :status => @status,
          :full_status => self.full_status
        }
        @headers = Rack::Utils::HeaderHash.new
        info.each do
          |k, v|
          if k.kind_of? Symbol
            @hal_properties[k] = v
          elsif k.kind_of?(String) and /^[\w][-\w]+$/i === k
            @headers[k] = v.to_s
          else
            raise ArgumentError, "#{k.class.name} found where a Symbol or String was expected."
          end
        end

        @hal_links = {}

        if message
          message = message.to_s
          @hal_properties[:message] = message
        else
          message = self.full_status
        end
        super message
      end


      # @param html [#to_s]
      # @return [String]
      # @deprecated in favor of nothing. This code was used back when there was an XHTML serialization of HTTPStatus.
      def self.escape_html html
        begin
          Nokogiri.XML(
          '<?xml version="1.0" encoding="UTF-8" ?>' +
          "<div>#{html}</div>"
          ) do |config| config.strict.nonet end
        rescue
          html = Rack::Utils.escape_html(html)
        end
        html.to_s
      end


      # @param request [Rackful::Request]
      # @return [Rack::Response]
      def to_response request
        response = Rack::Response.new
        response.status = self.status
        # Lint requires that status 304 (Not Modified) has no body and no
        # Content-Type response header.
        unless 304 === self.status
          representation = serializer(request, false)
          response['Content-Type'] = representation.content_type
          response.body = representation
          if representation.respond_to? :headers
            response.headers.merge!( representation.headers )
          end
          # Make sure the Location: response header contains an absolute URI:
          if response['Location'] and response['Location'][0] == ?/
            response['Location'] = ( self.canonical_uri + response['Location'] ).to_s
          end
        end
        # The next statement fixes a small peculiarity in RFC2616: the response body of a `HEAD` request _must_ be empty, even for responses outside 2xx.
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

      def initialize message = nil, info = {}
        /HTTP(\d\d\d)\w+\z/ === self.class.name
        super( $1.to_i, message )
      end

    end


    class HTTP201Created < HTTPStatus

      # @param locations [URI, String, Array<URI, String>]
      def initialize locations
        locations = [ locations ] unless locations.kind_of? Array
        locations = locations.collect do |location|
          HALLink(location)
        end
        if locations.size > 1
          super( 201 )
          @hal_links[:created] = locations
        elsif locations.size == 1
          location = locations[0]
          super( 201, nil, 'Location' => location.href.to_s )
          @hal_links[:created] = location
        else
          raise ArgumentError, "No Locations provided."
        end
      end

    end


    class HTTP202Accepted < HTTPStatus

      # @param location [URI, String, HALLink, Resource]
      def initialize location = nil
        if location
          location = HALLink(location)
          super( 202, nil, 'Location' => location.href.to_s )
          @hal_links[:status] = location
        else
          super 202
        end
      end

    end


    class HTTP301MovedPermanently < HTTPStatus

      # @param location [URI, String]
      def initialize location
        location = HALLink(location)
        super( 301, nil, 'Location' => location.href.to_s )
        @hal_links[:follow] = location
      end

    end


    class HTTP303SeeOther < HTTPStatus

      # @param location [URI, String]
      def initialize location
        location = HALLink(location)
        super( 303, nil, 'Location' => location.href.to_s )
        @hal_links[:follow] = location
      end

    end


    class HTTP304NotModified < HTTPSimpleStatus; end


    class HTTP307TemporaryRedirect < HTTPStatus

      # @param location [URI, String]
      def initialize location
        location = HALLink(location)
        super( 307, nil, 'Location' => location.href.to_s )
        @hal_links[:follow] = location
      end

    end


    class HTTP400BadRequest < HTTPSimpleStatus; end


    class HTTP401Unauthorized < HTTPStatus

      # @example Basic Authentication
      #     raise HTTP401Unauthorized.new('Basic', 'realm' => 'example.com')
      def initialize scheme, params = {}
        www_authenticate = scheme.to_s
        www_authenticate += ' ' + params.map { |name, value| "#{name}=\"#{value}\"" }.join(', ') unless params.empty?
        super( 401, nil, 'WWW-Authenticate' => www_authenticate, :parameters => params )
      end

    end


    class HTTP403Forbidden < HTTPSimpleStatus; end


    class HTTP404NotFound < HTTPSimpleStatus; end


    class HTTP405MethodNotAllowed < HTTPStatus

      def initialize methods
        super( 405, nil, 'Allow' => methods.join(', '), :allow => methods )
      end

    end


    class HTTP406NotAcceptable < HTTPStatus

      # @param media_types [Array<String>]
      def initialize media_types
        super( 406, nil, :acceptable => media_types )
      end

    end


    class HTTP409Conflict < HTTPSimpleStatus; end


    class HTTP410Gone < HTTPSimpleStatus; end


    class HTTP411LengthRequired < HTTPSimpleStatus; end


    class HTTP412PreconditionFailed < HTTPStatus

      def initialize header = nil
        super( 412, nil, header ? { :precondition => header } : {} )
      end

    end


    class HTTP413RequestEntityTooLarge < HTTPStatus

      def initialize max_length = nil
        super( 413, nil, max_length ? { :max_length => max_length } : {} )
      end

    end
    #Request-URI Too Long


    class HTTP414RequestURITooLong < HTTPStatus

      def initialize max_length = nil
        super( 414, nil, max_length ? { :max_length => max_length } : {} )
      end

    end


    class HTTP415UnsupportedMediaType < HTTPStatus

      def initialize media_types
        super( 415, nil, :supported => media_types )
      end

    end


    class HTTP422UnprocessableEntity < HTTPSimpleStatus; end


    class HTTP428PreconditionRequired < HTTPSimpleStatus; end


    class HTTP501NotImplemented < HTTPSimpleStatus; end


    class HTTP503ServiceUnavailable < HTTPSimpleStatus; end

  end # module Rackful::StatusCodes
end # module Rackful
