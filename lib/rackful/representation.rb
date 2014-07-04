# encoding: utf-8

# Required for parsing:
require_relative 'global.rb'
require_relative 'resource.rb'

# Required for running:


module Rackful

  # Mixin for representable {Resource resources}.
  #
  # This mixin should only be included *after* {Resource} has been included.
  module Representable

    include Resource

    module ClassMethods

      # Meta-programmer method.
      # @example Add a parser for `PUT` requests:
      #   class MyResource
      #     include Rackful::Resource
      #     include Rackful::Consumer
      #     add_parser MyXMLParser, :methods => :PUT
      #   end
      # @param parser [Parser]
      # @param opts [Hash] options
      # @option opts [Array<Symbol>, Symbol] :methods ([]) The method(s) for which this parser can be used, for example:
      #
      #   ```ruby
      #   add_parser MyParser                            # All methods. This is the default.
      #   add_parser MyParser, :methods => []            # Same as above.
      #   add_parser MyParser, :methods => :PUT          # Only handle PUT-requests.
      #   add_parser MyParser, :methods => [:POST, :PUT] # Handle POST- and PUT-requests.
      #   ```
      # @option opts [<Symbol>] :methods For which methods should this representation process the request entity?
      # @return [self]
      def add_parser parser, opts = {}
        opts[:methods] ||= []
        unless opts[:methods].kind_of?(Enumerable)
          opts[:methods] = [ opts[:methods] ]
        end
        opts[:methods] = opts[:methods].map { |v| v.to_sym }
        opts[:parser] = parser
        parsers << opts
        self
      end


      # Meta-programmer method.
      # @example Have your resource rendered in XML and JSON
      #   class MyResource
      #     include Rackful::Resource
      #     include Rackful::Representable
      #     add_serializer MyResource2XML
      #     add_serializer MyResource2JSON, 0.5
      #   end
      # @param serializer [Serializer]
      # @param quality [Float] The quality of this serializer for the calling resource.
      # @return [self]
      def add_serializer serializer, quality = 1.0
        quality = quality.nil? ? 1.0 : quality.to_f
        quality = 1.0 if quality > 1.0
        quality = 0.0 if quality < 0.0
        serializers[serializer.content_type] = [ serializer, quality ]
        self
      end


      # All representations for this class, including those added to parent classes.
      # The result of this method is cached, which will interfere with code reloading.
      # @return [Hash{ String( content_type ) => Hash{ :representation, :quality, :consume => Representation, Float, Boolean } }]
      # @api private
      def all_parsers
        # The single '@' on the following line is on purpose!
        @rackful_representable_all_parsers ||=
        if self.superclass.respond_to?(:all_parsers)
          self.superclass.all_parsers + parsers
        else
          parsers
        end
      end


      # All serializers for this class, including those added to parent classes.
      # The result of this method is cached, which will interfere with code reloading.
      # @return [Hash{ String( content_type ) => Hash{ :serializer, :quality, :consume => Serializer, Float, Boolean } }]
      # @api private
      def all_serializers
        # The single '@' on the following line is on purpose!
        @rackful_representable_all_serializers ||=
        if self.superclass.respond_to?(:all_serializers)
          self.superclass.all_serializers.merge( serializers )
        else
          serializers
        end
      end


      # @see ClassMethods::extended
      # @api private
      def rackful_representable_classmethods_reset
        # The single '@' on the following lines is on purpose!
        @rackful_representable_all_parsers = nil
        @rackful_representable_parsers = []
        @rackful_representable_all_serializers = nil
        @rackful_representable_serializers = {}
      end


      # @param serializer [Serializer]
      # @return [Boolean]
      def has_serializer? serializer
        @rackful_representable_represented_by ||= {}
        unless @rackful_representable_represented_by.has_key? serializer
          @rackful_representable_represented_by[serializer] =
          all_serializers.any? { |r| r[0].equal?(serializer) }
        end
        @rackful_representable_represented_by[serializer]
      end


      # @api private
      # @see Representable
      def self.extended(mod)
        mod.rackful_representable_classmethods_reset
      end

      private


      # All representations added to _this_ class.  Ie. not including representations added
      # to parent classes.
      # @return [Array< Hash(info) >] Where `info` has the following members:
      #
      #   *   **`:parser`:** a {Parser} class
      #   *   **`:methods`:** an Array of Symbols
      def parsers
        @rackful_representable_parsers ||= []
      end


      # All serializers added to _this_ class.  Ie. not including serializers added
      # to parent classes.
      # @return [Hash{ String(content_type) => Hash(info) }] Where `info` has the following members:
      #
      #   *   **`:serializer`:** a {Serializer} class
      #   *   **`:quality`:** a real value in the range [ 0.0 .. 1.0 ]
      def serializers
        @rackful_representable_serializers ||= {}
      end

    end # module ClassMethods


    # This callback includes all methods of {ClassMethods} into all classes that
    # include this module, to make them available as a tiny DSL.
    # @api private
    def self.included(mod)
      raise "Module #{self.name} should only be included in classes, not in other modules." unless mod.kind_of?( Class )
      raise "Include Rackful::Resource before #{self.name}." unless mod.include?( Resource )
      mod.extend ClassMethods
    end


    # @see Resource#http_PUT
    def parser request
      supported_media_types = []
      retval = self.class.all_parsers.reverse_each.find do
        |p|
        next unless p[:methods].empty? or p[:methods].include? request.request_method.to_sym
        klass = p[:parser]
        media_type = klass.media_type
        supported_media_types << media_type
        File.fnmatch( media_type, request.media_type, File::FNM_PATHNAME )
      end
      if retval
        retval[:parser].new( request, self )
      else
        raise HTTP415UnsupportedMediaType, supported_media_types
      end
    end


    # @overload serializer( request, require_match = true )
    #   @param request [Request] the request object for the current request.
    #   @param require_match [Boolean] determines what must happen if the client sent an `Accept:` header, and we cannot serve any of the acceptable media types. **`TRUE`** means that an {HTTP406NotAcceptable} exception is raised in this case. **`FALSE`** means that the serializer with the highest serializeral quality is returned.
    #   @return [Serializer] The best serializer of this resource, given the current HTTP request.
    #   @raise [HTTP406NotAcceptable]
    # @overload serializer( request, serializer_class )
    #   @param request [Request] the request object for the current request.
    #   @param serializer_class [Class] the required class of the returned serializer.
    #   @return [Serializer] A serializer for the target object.
    #   @raise [RuntimeError] if no serializer of the required class can be produced.
    def serializer( request, thing = true )
      if thing.kind_of? Class
        unless self.class.represented_by? thing
          raise "Resources of class %s cannot be represented by %s." % [ self.class, thing.name ]
        end
        return thing.new( request, self )
      end
      default_serializer =
      self.class.all_serializers. # Hash{ String(content_type) => Array(Serializer, Float) }
      values.sort_by { |o| o[1] }. # Array< Array(Serializer, Float) >
      last[0] # Serializer
      best_match = [ default_serializer, 0.0 ]
      request.q_values.each do
        |accept_media_type, accept_quality|
        self.class.all_serializers.each_pair do
          |content_type, r|
          media_type = content_type.split(/\s*;/).first
          qq = accept_quality * r[1]
          if File.fnmatch( accept_media_type, media_type, File::FNM_PATHNAME ) and best_match[1] < qq
            best_match = [ r[0], qq ]
          end
        end
      end
      if thing and request.env['HTTP_ACCEPT'] and best_match[1] <= 0.0
        raise( HTTP406NotAcceptable, self.class.all_serializers.keys.map { |ct| ct.split(/\s*;/).first } )
      end
      best_match[0].new(request, self)
    end


    # @api private
    # @param request [Rackful::Request]
    # @param response [Rack::Response]
    # @raise [HTTP406NotAcceptable]
    def do_GET request, response
      if self.class.all_serializers.empty?
        raise "No serializers found for class %s" % self.class.name
      end
      # May throw HTTP406NotAcceptable:
      serializer = serializer( request )
      response['Content-Type'] = serializer.content_type
      if serializer.respond_to? :headers
        response.headers.merge!( serializer.headers )
      end
      response.body = serializer
    end
  end # module Rackful::Resource


  # Base class for all parsers.
  #
  # @!attribute [r] request
  #   @return [Request]
  #
  # @!attribute [r] resource
  #   @return [Resource]
  class Parser

    class << self

      # @param media_type [String]
      # @return [self]
      def consumes media_type
        @rackful_parser_media_type = media_type.to_s
        unless %r{\A[a-z*]+/[a-z*]+(?:[\-+][a-z*]+)*\z}i === @rackful_parser_media_type
          raise <<-EOS
            Mime Type should be of the form <registry>/<type>, without any parameters.
            Use the asterisk for wildcard matching.
            Examples: text/plain text/*+xml */*
          EOS
        end
        media_type
      end


      # Mime-Type consumed by this serializer.
      #
      # If a media type was set with {#media_type=}, returns that media type. Otherwise, it returns the media type part of the `Content-Type` set with {#content_type=}.
      # @return [String] media type consumed by this serializer
      def media_type
        @rackful_parser_media_type ||= begin
          superclass.media_type
        rescue
          raise "Parser %s doesn’t define a media type!" % self.name
        end
      end


    end
    include StatusCodes


    attr_reader :request


    # @param request [Request]
    def initialize request
      @request = request
    end


    # Shortcut for {Parser.media_type}
    # @return (see Parser.media_type)
    def media_type
      self.class.media_type
    end


  end # class Parser


  # Utility parent class of all XML serializers.
  # @abstract
  # @since 0.2.0
  class Parser::XML < Parser

    # @return [Nokogiri::XML::Document]
    # @raise [HTTP400BadRequest] if the document is malformed.
    def document
      begin
        require 'nokogiri'
      rescue
        raise "Cannot parse XML, because gem “nokogiri” isn’t installed."
      end
      unless @document
        # TODO Is ISO-8859-1 indeed the default encoding for XML documents? If so,
        # that fact must be documented and referenced.
        encoding = request.media_type_params['charset'] || 'ISO-8859-1'
        begin
          @document = Nokogiri.XML(
          request.env['rack.input'].read,
          request.canonical_uri.to_s,
          encoding
          ) do |config|
            config.strict.nonet
          end
        rescue
          raise HTTP400BadRequest, $!.to_s
        end
        raise( HTTP400BadRequest, $!.to_s ) unless @document.root
      end
      @document
    end


  end # class Parser::XML


  # Base class for all serializers.
  #
  # Serializer instances are to be used as the {Rack::Response#body body of a Rack Response object}, which means it must respond to `#each`. Including {Enumerable} seems only logical.


  #
  # The serializers defined in Rackful depend on the presence of methods {Rackful::Resource#to_rackful resource.to_rackful}.
  # @abstract Subclasses MUST implement `#each`.
  # @example Create a new Serializer subclass:
  #   class MySerializer < Rackful::Serializer
  #     produces = 'text/plain; charset="UTF-8"'
  #     def each
  #       yield "Hello world! I'm a " + resource.class.name
  #     end
  #   end
  #
  # @!attribute [r] request
  #   @return [Request]
  #
  # @!attribute [r] resource
  #   @return [Resource]
  #
  # @!method headers()
  #   Extra response headers that a serializer likes to return.
  #
  #   You shouldn’t return a `Content-Type` header, as this is done _for_ you.
  #
  #   This method is optional.
  #   @return [Hash{String(header_name) => String(header_value)}]
  #
  # @!method each(&block)
  #   Yields the serializer, in chunks.
  #   @abstract Every serializer MUST implement this method.
  #   @yieldparam block [String] (a chunk of) the entity body
  #   @return [void]
  class Serializer
    include Enumerable
    include StatusCodes

    class << self

      # @param content_type [String]
      # @return [self]
      def produces content_type
        @rackful_serializer_content_type = content_type.to_s
        unless %r{^[a-z]+/[a-z]+(?:[\-+][a-z]+)*(?:;.+)?$}i === @rackful_serializer_content_type
          raise <<-EOS
Content-Type should be of the form <registry>/<type>, optionally followed by content-type parameters. Examples:
text/plain
text/html; charset="utf-8"
          EOS
        end
        self
      end


      # @return [String] Content-Type of this serializer class.
      def content_type
        @rackful_serializer_content_type ||= begin
          superclass.content_type
        rescue
          raise "Serializer %s doesn’t define a content type!" % self.name
        end
      end

    end

    attr_reader :request, :resource


    # @param request [Request]
    # @param resource [Resource]
    # @param content_type [String]
    def initialize request, resource
      @request, @resource = request, resource
    end


    # Shortcut for {Serializer.content_type}
    # @return (see Serializer.content_type)
    def content_type
      self.class.content_type
    end


  end # class Serializer

end # module Rackful
