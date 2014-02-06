# encoding: utf-8


module Rackful::WebDAV


# @deprecated unused
class Property


  # @api private
  def self.codecs; @codecs ||= {}; end


=begin markdown
Throughout this documentation, the term _property-name_ is used. By this,
we mean the namespace URL and local name of the property, separated by a space.
For example: `"DAV: getcontentlength"`

    property-name = namespaceURL + " " + localname
@return [String] the property-name
=end
  attr_reader :name


=begin markdown
@overload initialize(xml_element)
  @param xml_element [Nokogiri::XML::Element]
  @example
    property = Property.new document.at_xpath('/some/path')
@overload initialize(property_name)
  @param property_name [String]
  @example
    property = Property.new 'DAV: getcontentlength'
  @todo implement
@overload initialize(xml_element_string)
  @param xml_element_string [String]
  @example
    property = Property.new '<foo>bar</foo>'
=end
  def initialize p
    if /\A(\S*) ([^\s:]+)\z/ === name
      @name = name
    else
      if p.kind_of Nokogiri::XML::Element
        @doc = Nokogiri::XML::Document.new
        @doc.encoding = 'UTF-8'
        @doc.root = p
      elsif p.respond_to?( :to_str ) && p.to_str[0] == '<'
        @doc = Nokogiri::XML::Document.parse(
          '<?xml version="1.0" encoding="utf-8"?>' + p
        )
      else
        raise "Don’t know what to do with parameter value #{p.inspect}"
      end
      @name = ( @element.namespace ? @element.namespace.href : '' ) + ' ' + @element.node_name
    end
  end


  # @deprecated Don’t know what this code will do yet
  def from_s
    doc = Nokogiri::XML::Document.new
    doc.encoding = 'UTF-8'
    doc.root = case $0
      when 'DAV:'
        doc.create_element( "D:#{$1}", 'xmlns:D' => 'DAV:' )
      when ''
        doc.create_element( $1 )
      else
        doc.create_element( $1, 'xmlns' => $0 )
    end
  end


  def element; @doc.root; end


  def to_s
    @doc.root.to_xml
  end


  def value
    unless codec = self.class.codecs[ self.name ]
      raise HTTP501NotImplemented, "No Codec implemented for property '#{self.name}'"
    end
    codec.decode(@doc.root)
  end


end # class Property


class Codec


  # @api private
  def self.codecs; @codecs ||= {}; end


  def self.[] property_name
    self.codecs[property_name]
  end


  def self.register property_name, codec
    self.codecs[property_name] = codec
  end


  def initialize
    if block_defined?
      yield self
    end
  end


=begin markdown
@param value [Mixed]
@return [String] a serialized XML element
=end
  def encode value; raise HTTP501NotImplemented, "#{self.class}#encode"; end


=begin markdown
@param node [Nokogiri::XML::Element]
@return [Mixed]
=end
  def decode node; raise HTTP501NotImplemented, "#{self.class}#decode"; end


end # class Codec


Codec.register(
  'DAV: creationdate',
  Codec.new do |codec|
    def codec.encode value
      "<D:creationdate>#{Time.at(value.to_i).utc.xmlschema}</D:creationdate>"
    end
    def codec.decode node
      Time.xmlschema(node.inner_text.strip)
    end
  end
)


Codec.register(
  'DAV: displayname',
  Codec.new do |codec|
    def codec.encode value
      "<D:displayname>#{Rack::Utils.escape_html(value.to_s)}</D:displayname>"
    end
    def codec.decode node
      node.inner_text.strip
    end
  end
)


Codec.register(
  'DAV: getcontentlanguage',
  Codec.new do |codec|
    def codec.encode value
      "<D:getcontentlanguage>#{Rack::Utils.escape_html(value.to_s)}</D:getcontentlanguage>"
    end
    def codec.decode node
      node.inner_text.strip
    end
  end
)


Codec.register(
  'DAV: getcontentlength',
  Codec.new do |codec|
    def codec.encode value
      "<D:getcontentlength>#{value.to_i}</D:getcontentlength>"
    end
  end
)


Codec.register(
  'DAV: getcontenttype',
  Codec.new do |codec|
    def codec.encode value
      "<D:getcontentlength>#{Rack::Utils.escape_html(value.to_s)}</D:getcontentlength>"
    end
    def codec.decode node
      node.inner_text.strip
    end
  end
)


Codec.register(
  'DAV: getetag',
  Codec.new do |codec|
    def codec.encode value
      '<D:getetag>"' + Rack::Utils.escape_html(
        value.to_s.gsub('"', '\\"')
      ) + '"</D:getetag>'
    end
    def codec.decode node
      etag = node.inner_text.strip
      unless /\A"(?:\\.|[^\\"])+"\z/ === etag
        raise HTTP400BadRequest, "Invalid ETag: #{etag}"
      end
      etag
    end
  end
)


Codec.register(
  'DAV: getlastmodified',
  Codec.new do |codec|
    def codec.encode value
      "<D:getlastmodified>#{Time.at(value.to_i).httpdate}</D:getlastmodified>"
    end
    def codec.decode node
      Time.httpdate(node.inner_text.strip)
    end
  end
)


Codec.register(
  'DAV: resourcetype',
  Codec.new do |codec|
    def codec.encode value
      "<D:resourcetype>#{value}</D:resourcetype>"
    end
  end
)


end # module Rackful::WebDAV
