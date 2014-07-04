# encoding: utf-8

# Required for parsing:
require_relative '../representation.rb'

# Required for running:
require 'json'


module Rackful

  # Casts the operand to a HALLink if necessary
  # @param thing [#to_s, URI, Resource, HALLink]
  # @return [HALLink, thing]
  def self.HALLink thing
    if thing.kind_of? HALLink
      thing
    elsif thing.kind_of? Resource and thing.uri
      HALLink.new(thing.uri)
    elsif thing.respond_to? :to_str
      HALLink.new(thing)
    else
      raise ArgumentError, "Can’t cast #{thing.class.name} to HALLink."
    end
  end


  # A Link Object as defined in [JSON Hypertext Application Language, §5](http://tools.ietf.org/html/draft-kelly-json-hal-06#section-5).
  # The advantage of having a special class for HAL Links over just using a plain {Hash} or {OpenStruct} is that this class does some content validation, and has a {#initialize nice constructor}.
  #
  # @!attribute deprecation
  #   Indicates that the link is to be deprecated (i.e. removed) at a future date.
  #   @return [URI] SHOULD provide further information about the deprecation.
  #
  # @!attribute href
  #   @return [URI]
  #
  # @!attribute hreflang
  #   The language of the target resource (as defined by [RFC5988](http://tools.ietf.org/html/rfc5988)).
  #   @return [String]
  #
  # @!attribute name
  #   Secondary key for selecting Link Objects which share the same relation type.
  #   @return [String]
  #
  # @!attribute profile
  #   The profile (as defined by <http://tools.ietf.org/html/draft-wilde-profile-link-04>) of the target resource.
  #   @return [URI]
  #
  # @!attribute title
  #   A human-readable identifier (as defined by [RFC5988](http://tools.ietf.org/html/rfc5988)).
  #   @return [String]
  #
  # @!attribute type
  #   The media type of the linked resource.
  #   @return [String]
  class HALLink

    # @overload initialize(href, opts = {})
    #   Create a new HALLink object from scratch.
    #   @param href [URI]
    #   @param opts [Hash]
    #   @option opts [URI] deprecation see {#deprecation}
    #   @option opts [String] hreflang see {#hreflang}
    #   @option opts [String] name see {#name}
    #   @option opts [URI] profile see {#profile}
    #   @option opts [String] title see {#title}
    #   @option opts [String] type see {#type}
    #
    # @overload initialize(parsed_json)
    #   Convert a bit of parsed HAL JSON to a HALLink object.
    #   @param parsed_json [Hash]
    #
    # @overload initialize(href, resource)
    #   Create a HALLink object for the provided resource. If the resource responds to `hal_deprecation`, `hal_hreflang`, `hal_name`, `hal_profile`, `hal_title` or `hal_type`, then these properties are added to the new HALLink.
    #   @param href [URI]
    #   @param resource [Resource]
    def initialize thing, opts = {}
      @data = {}
      if opts.kind_of? Resource
        self.href        = thing
        self.deprecation = opts.hal_deprecation if opts.respond_to?(:hal_deprecation)
        self.hreflang    = opts.hal_hreflang    if opts.respond_to?(:hal_hreflang)
        self.name        = opts.hal_name        if opts.respond_to?(:hal_name)
        self.profile     = opts.hal_profile     if opts.respond_to?(:hal_profile)
        self.title       = opts.hal_title       if opts.respond_to?(:hal_title)
        if opts.kind_of?(Representable) and 1 == opts.class.all_serializers.size
          self.type      = opts.class.all_serializers.keys.first
        end
      else
        if thing.kind_of? Hash and opts.empty?
          opts = thing
          raise HTTP400BadRequest, "Original JSON doesn’t contain required field \"href\".\n#{opts.to_json}"
        else
          opts[:href] = thing
        end
        self.deprecation = opts[:deprecation] if opts.has_key? :deprecation
        self.href = opts[:href]
        self.hreflang = opts[:hreflang] if opts.has_key? :hreflang
        self.name = opts[:name] if opts.has_key? :name
        self.profile = opts[:profile] if opts.has_key? :profile
        self.title = opts[:title] if opts.has_key? :title
        self.type = opts[:type] if opts.has_key? :type
      end
    end


    def to_json
      @data.to_json
    end


    private


    def self.add_uri_attributes *attributes
      attributes.each do
        |a|
        class_eval %{
          def #{a}; @data[:#{a}]; end
          def #{a}= v
            if v.nil?
              @data.delete :#{a}
            else
              @data[:#{a}] = URI(v)
            end
            v
          end
        }
      end
    end


    def self.add_string_attributes *attributes
      attributes.each do
        |a|
        class_eval %{
          def #{a}; @data[:#{a}]; end
          def #{a}= v
            if v.nil?
              @data.delete :#{a}
            else
              @data[:#{a}] = v.to_s
            end
            v
          end
        }
      end
    end

    add_uri_attributes :deprecation, :href, :profile
    add_string_attributes :hreflang, :name, :title, :type

  end


  class Serializer::HALJSON < Serializer


    produces 'application/hal+json'

    # @yield [json]
    # @yieldparam json [String]
    def each thing = self.resource, &block
      if thing.kind_of? Representable
        if ! thing.equal? resource
          thing.serializer( request, self.class ).each( &block )
        else
          # In this case, thing == resource(). We use `thing`, for consistency.
          first = true
          yield '{'
          links = thing.respond_to?(:hal_links) ? thing.hal_links.dup : {}
          if ! links.has_key?(:self) and thing.uri
            links[:self] = HALLink.new(thing.uri)
          end
          # Sanity check: All objects in the `links` structure must be of class `HALLink`.
          unless links.all? { |k,v| v.kind_of?(HALLink) or v.kind_of?(Enumerable) && v.all? { |h| h.kind_of? HALLink } }
            raise "Non-HALLink objects found in return value of %s#hal_links()" % thing.class.name
          end
          unless links.empty?
            yield '"_links":'
            each links, &block
            first = false
          end
          embedded = thing.respond_to?(:hal_embedded) ? thing.hal_embedded : {}
          unless embedded.empty?
            # Sanity check: All objects in the `links` structure must be of class `HALLink`.
            unless embedded.all? { |k,v| v.kind_of?(Representable) or v.kind_of?(Enumerable) && v.all? { |h| h.kind_of? Representable } }
              raise "Non-Representable objects found in return value of %s#hal_embedded()" % thing.class.name
            end
            if first
              yield '"_embedded":'
              first = false
            else
              yield ',"_embedded":'
            end
            each embedded, &block
          end
          if thing.respond_to? :hal_properties
            thing.hal_properties.each_pair do
              |k,v|
              if first
                yield k.to_json + ':'
                first = false
              else
                yield ',' + k.to_json + ':'
              end
              each v, &block
            end
          end
          yield '}'
        end
      elsif thing.respond_to? :each_pair
        first = true
        thing.each_pair do
          |k, v|
          yield( ( first ? "{" : "," ) + k.to_s.to_json + ":" )
          first = false
          each v, &block
        end
        yield( first ? "{}" : "}" )
      elsif thing.respond_to? :each
        first = true
        thing.each do
          |v|
          yield( first ? "[" : "," )
          first = false
          each v, &block
        end
        yield( first ? "[]" : "]" )
      elsif thing.kind_of?( String ) && thing.encoding == Encoding::BINARY
        yield Base64.strict_encode64(thing).to_json
      elsif thing.kind_of?( Time )
        yield thing.utc.xmlschema.to_json
      else
        yield thing.to_json
      end
    end


  end # class Serializer::HALJSON


  class Parser::HALJSON < Parser

    consumes 'application/hal+json'

    # @return [URI] the URI of the {Resource} this document is about.
    def context_uri
      if ( self_links = self.hal_links[:self] )
        self_links.first.href
      else
        request.canonical_uri
      end
    end


    # @return [ Hash{ Symbol => Array< HALLink > } ]
    def hal_links
      parse[:_links]
    end


    # @return [ Hash{ Symbol => Object } ]
    def hal_properties
      @hal_properties ||= begin
        retval = parse.dup
        retval.delete :_links
        retval.delete :_embedded
        retval
      end
    end


    # @return [ Hash{ Symbol => Array< Hash > } ]
    def hal_embedded
      parse[:_embedded]
    end

    private


    def parse
      @data ||= begin
        begin
          data = ::JSON.parse( request.env['rack.input'].read, :symbolize_names => true )
          raise HTTP400BadRequest, "JSON object expected" unless data.kind_of? Hash
        rescue
          raise HTTP400BadRequest, $!.message
        end
        recursive_time_parser( recursive_embedded_parser( data ) )
      end
    end


    # Checks if `p` might contain an XML Schema-like DateTime value or a URI.
    # Returns a {Time} or {URI} object respectively. If `p` is an {Array} or {Hash}-like object, it is traversed recursively.
    # @param p [Mixed]
    # @return [Mixed]
    def recursive_time_parser p
      if p.kind_of?(String)
        begin
          return Time.xmlschema(p)
        rescue ArgumentError
        end
      elsif p.respond_to? :each_with_index
        p.each_with_index do
          |value, key|
          p[key] = recursive_time_parser( value ) unless :_links == key
        end
      end
      p
    end


    # Traverses structure `p`, transforming Hashes to {HALLink HALLinks} where appropriate, and ensuring each value in `p` is an Array
    # **WARNING: the content of `p` is modified *in place*.**
    # @param p [ Hash{ Symbol => Hash, Array<Hash> } ]
    # @return [ Hash{ Symbol => Array<HALLink> } ]
    # @raise [HTTP400BadRequest]
    def links_parser p
      raise HTTP400BadRequest, "#{p.class.name} found where Hash was expected." unless p.kind_of?(Hash)
      p.each_pair do
        |name, links|
        unless links.kind_of?(Array)
          links = [ links ]
        end
        if links.empty?
          p.delete(name)
        else
          p[name] = links.map do
            |link|
            raise HTTP400BadRequest, "#{link.class.name} found where Hash was expected." unless link.kind_of?(Hash)
            HALLink.new link
          end
        end
      end
      p
    end


    # Traverses structure `p`, transforming Hashes to Arrays of Hashes where appropriate, ensuring each value in `p[:_embedded]` is an Array.
    # **WARNING: the content of `p` is modified *in place*.**
    # @param p [ Hash{ Symbol(:_embedded) => Hash{ Symbol => Hash, Array<Hash> } } ]
    # @return [ Hash(HAL_resource) ]
    # @raise [HTTP400BadRequest]
    def recursive_embedded_parser p
      p[:_links] = p[:_links] ? links_parser( p[:_links] ) : {}
      e = ( p[:_embedded] ||= {} )
      raise HTTP400BadRequest, "#{e.class.name} found where Hash was expected." unless e.kind_of?(Hash)
      e.each_pair do
        |name, resources|
        unless resources.kind_of?(Array)
          resources = [ resources ]
        end
        if resources.empty?
          e.delete(name)
        else
          e[name] = resources.map do
            |r|
            raise HTTP400BadRequest, "#{e.class.name} found where Hash was expected." unless e.kind_of?(Hash)
            recursive_embedded_parser r
          end
        end
      end
      p
    end

  end # class Parser::HALJSON


end # module Rackful
