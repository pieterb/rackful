# encoding: utf-8


module Rackful


=begin markdown
Base class for all parsers.
@abstract Subclasses must implement method `#parse`, and define constant
  {MEDIA_TYPES} as an array of media types this parser accepts.
@example Subclassing this class
  class MyTextParser < Rackful::Parser
    MEDIA_TYPES = [ 'text/plain' ]
    def parse
      # YOUR CODE HERE...
    end
  end
=end
class Parser


=begin markdown
@const MEDIA_TYPES
  @return [Array<String>] An array of media type strings.
=end


  # @return [Request]
  attr_reader :request
  # @return [Resource]
  attr_reader :resource


=begin markdown
@param request [Request]
@param resource [Resource]
=end
  def initialize request, resource
    @request, @resource = request, resource
  end


end # class Parser


=begin markdown
Parent class of all XML-parsing parsers.
@abstract
@since 0.2.0
=end
class Parser::DOM < Parser


=begin markdown
The media types parsed by this parser.
@see Parser
=end
  MEDIA_TYPES = [
    'text/xml',
    'application/xml'
  ]


=begin markdown
@return [Nokogiri::XML::Document]
=end
  attr_reader :document


=begin markdown
@raise [HTTP400BadRequest] if the document is malformed.
=end
  def initialize request, resource
    super
    encoding = self.request.media_type_params['charset'] || 'ISO-8859-1'
    begin
      @document = Nokogiri.XML(
        self.request.env['rack.input'].read,
        self.request.canonical_url.to_s,
        encoding
      ) do |config|
        config.strict.nonet
      end
    rescue
      raise HTTP400BadRequest, $!.to_s
    end
  end


end # class Parser::DOM


=begin markdown
Parses XHTML as generated by {Serializer::XHTML}.
=end
class Parser::XHTML < Parser::DOM


=begin markdown
The media types parsed by this parser.
@see Parser
=end
  MEDIA_TYPES = Parser::DOM::MEDIA_TYPES + [
    'application/xhtml+xml',
    'text/html'
  ]


=begin markdown
@see Parser#parse
=end
  def parse
    # Try to find the actual content:
    content = self.document.root.xpath(
      '//html:div[@id="rackful-content"]',
      'html' => 'http://www.w3.org/1999/xhtml'
    )
    # There must be exactly one element <div id="rackful_content"/> in the document:
    if content.empty?
      raise HTTP400BadRequest, 'Couldn’t find div#rackful-content in request body.'
    end
    if content.length > 1
      raise HTTP400BadRequest, 'Multiple instances of div#rackful-content found in request body.'
    end
    # Initialize @base_url:
    base_url = self.document.root.xpath(
      '/html:html/html:head/html:base',
      'html' => 'http://www.w3.org/1999/xhtml'
    )
    if base_url.empty?
      @base_url = self.request.canonical_url.dup
    else
      @base_url = URI( base_url.first.attribute('href').text ).normalize
      if @base_url.relative?
        @base_url = self.request.canonical_url + @base_url
      end
    end
    # Parse the f*cking thing:
    self.parse_recursive content.first
  end


=begin markdown
@api private
=end
  def parse_recursive node

    # A URI:
    if ( nodelist = node.xpath( 'html:a', 'html' => 'http://www.w3.org/1999/xhtml' ) ).length == 1
      r = URI( nodelist.first.attribute('href').text )
      r.relative? ? @base_url + r : r

    # An Object (AKA a Hash)
    elsif ( nodelist = node.xpath( 'html:dl', 'html' => 'http://www.w3.org/1999/xhtml' ) ).length == 1
      self.parse_object nodelist.first

    # A list of Objects with identical keys:
    elsif ( nodelist = node.xpath( 'html:table', 'html' => 'http://www.w3.org/1999/xhtml' ) ).length == 1
      self.parse_object_list nodelist.first

    # A list of things (AKA an Array):
    elsif ( nodelist = node.xpath( 'html:ul', 'html' => 'http://www.w3.org/1999/xhtml' ) ).length == 1
      nodelist.first.xpath(
        'html:li',
        'html' => 'http://www.w3.org/1999/xhtml'
      ).collect do |n| self.parse_recursive n end

    # A simple type:
    elsif type = node.attribute_with_ns( 'type', 'http://www.w3.org/2001/XMLSchema' )
      prefix, typename = type.text.split(':', 2)
      unless typename && 'http://www.w3.org/2001/XMLSchema' == node.namespaces["xmlns:#{prefix}"]
        raise HTTP400BadRequest, "Unknown XML Schema type: #{type}"
      end
      self.parse_simple_type node, typename
    else
      raise HTTP400BadRequest, 'Can’t parse:<br/>' + Rack::Utils.escape_html(node.to_xml)
    end
  end


=begin markdown
@api private
=end
  def parse_simple_type node, typename
    case typename
    when 'boolean'
      case node.inner_text.strip
      when 'true'  then true
      when 'false' then false
      else nil
      end
    when 'integer'
      node.inner_text.strip.to_i
    when 'numeric'
      node.inner_text.strip.to_f
    when 'dateTime'
      Time.xmlschema(node.inner_text.strip)
    when 'base64Binary'
      Base64.decode64(node.inner_text)
    when 'string'
      node.inner_text
    else
      raise HTTP400BadRequest, "Unknown XML Schema type: #{type}"
    end
  end


=begin markdown
@api private
=end
  def parse_object node
    current_property = nil
    r = {}
    node.children.each do |child|
      if 'dt' == child.name &&
         'http://www.w3.org/1999/xhtml' == child.namespace.href
        if current_property
          raise HTTP400BadRequest, 'Can’t parse:<br/>' + Rack::Utils.escape_html(node.to_xml)
        end
        current_property = child.inner_text.strip.split(' ').join('_').to_sym
      elsif 'dd' == child.name &&
            'http://www.w3.org/1999/xhtml' == child.namespace.href
        unless current_property
          raise HTTP400BadRequest, 'Can’t parse:<br/>' + Rack::Utils.escape_html(node.to_xml)
        end
        r[current_property] = self.parse_recursive( child )
        current_property = nil
      end
    end
    r
  end


=begin markdown
@api private
=end
  def parse_object_list node
    properties = node.xpath(
      'html:thead/html:tr/html:th',
      'html' => 'http://www.w3.org/1999/xhtml'
    ).collect do |th|
      th.inner_text.strip.split(' ').join('_').to_sym
    end
    if properties.empty?
      raise HTTP400BadRequest, 'Can’t parse:<br/>' + Rack::Utils.escape_html(node.to_xml)
    end
    n = properties.length
    node.xpath(
      'html:tbody/html:tr',
      'html' => 'http://www.w3.org/1999/xhtml'
    ).collect do |row|
      values = row.xpath(
        'html:td', 'html' => 'http://www.w3.org/1999/xhtml'
      )
      unless values.length == n
        raise HTTP400BadRequest, 'Can’t parse:<br/>' + Rack::Utils.escape_html(row.to_xml)
      end
      object = {}
      Range.new(0,n-1).each do |i|
        object[properties[i]] = self.parse_recursive( values[i] )
      end
      object
    end
  end


end # class Parser::XHTML


class Parser::JSON < Parser


  MEDIA_TYPES = [
    'application/json',
    'application/x-json'
  ]


  def parse
    r = ::JSON.parse(
      self.request.env['rack.input'].read,
      :symbolize_names => true
    )
    self.recursive_datetime_parser r
  end


  def recursive_datetime_parser p
    if p.kind_of?(String)
      begin
        return Time.xmlschema(p)
      rescue
      end
    elsif p.kind_of?(Hash)
      p.keys.each do
        |key|
        p[key] = self.recursive_datetime_parser( p[key] )
      end
    elsif p.kind_of?(Array)
      (0 ... p.size).each do
        |i|
        p[i] = self.recursive_datetime_parser( p[i] )
      end
    end
    p
  end


end # class Parser::JSON


end # module Rackful
