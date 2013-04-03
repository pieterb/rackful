# encoding: utf-8


module Rackful


=begin markdown
Base class for all serializers.

The default serializer defined in this library ({Rackful::XHTML})
depends on the availability of method {Rackful::Resource#to_rackful resource.to_rackful}.
@abstract Subclasses must implement method `#each` end define constant `CONTENT_TYPES`
@!attribute [r] request
  @return [Request]
@!attribute [r] resource
  @return [Resource]
@!attribute [r] content_type
  @return [String] The content type to be served by this Serializer.
=end
class Serializer


  include Enumerable


  attr_reader :request, :resource, :content_type


=begin markdown
@param request [Request]
@param resource [Resource]
@param content_type [String]
=end
  def initialize request, resource, content_type
    @request, @resource, @content_type =
      request, resource, content_type
  end


=begin markdown
@!method headers()
  Extra response headers that a serializer likes to return.

  You don't have to include the `Content-Type` header, as this is done _for_ you.

  This method is optional.
  @return [Hash]
  @abstract
=end


=begin markdown
@abstract Every serializer must implement this method.
@yieldparam block [String] (part of) the entity body
=end
  def each
    raise NotImplementedError
  end


end # class Serializer


=begin markdown
=end
class Serializer::XHTML < Serializer


  # The content types served by this serializer.
  # @see Serializer::CONTENT_TYPES
  CONTENT_TYPES = [
    'application/xml; charset=UTF-8',
    'text/xml; charset=UTF-8',
    'text/html; charset=UTF-8',
    'application/xhtml+xml; charset=UTF-8',
  ]


=begin markdown
@yieldparam xhtml [String]
=end
  def each &block
    tmp = ''
    # The XML header is only sent for XML media types:
    if /xml/ === self.content_type
      tmp += <<EOS
<?xml version="1.0" encoding="UTF-8"?>
EOS
    end
    tmp += <<EOS
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:xs="http://www.w3.org/2001/XMLSchema">
<head>
<title>#{ Rack::Utils.escape_html(resource.title) }</title>
<base href="#{self.request.content_location}"/>
EOS
    unless '/' == self.request.path
      tmp += <<EOS
<link rel="contents" href="#{'/' === self.request.content_location[-1] ? '../' : './' }"/>
EOS
    end
    r = self.resource.to_rackful
    tmp += self.header + '<div id="rackful-content"' + self.xsd_type( r ) + '>'
    yield tmp
    each_nested( r, &block )
    yield '</div>' + footer
  end


=begin markdown
@api private
=end
  def header
    self.class.class_variable_defined?( :@@header ) && @@header ?
      @@header.call( self ) :
      "</head><body>"
  end


=begin markdown
Set a header generator.
@yieldparam serializer [Serializer::XHTML] This serializer
@yieldreturn [String] some XHTML
=end
  def self.header &block
    @@header = block
    self
  end


=begin markdown
@api private
=end
  def footer
    self.class.class_variable_defined?( :@@footer ) && @@footer ?
      @@footer.call( self ) :
      '<div class="rackful-powered">Powered by <a href="http://github.com/pieterb/Rackful">Rackful</a></div></body></html>'
  end


=begin markdown
Set a footer generator.
@yieldparam serializer [Serializer::XHTML] This serializer
@yieldreturn [String] some XHTML
=end
  def self.footer &block
    @@footer = block
    self
  end


=begin markdown
Serializes many kinds of objects to XHTML.

How an object is serialized, depends:

*   A *{Resource}* will be serialized by its own {Resource#serializer serializer}.
*   A *{URI}* will be serialized as a hyperlink.
*   An Object responding to *`#each_pair`* (i.e. something {Hash}-like) will
    be represented by
    *   a descriptive list, with
*   An Object responding to *`#each`* (i.e. something {Enumerable}) will
    be represented as a JSON array.
*   A *binary encoded {String}* (i.e. a blob} is represented by a JSON string,
    containing the base64 encoded version of the data.
*   A *{Time}* is represented by a string containing a dateTime as defined by
    XMLSchema.
*   On *all the rest,* method `#to_json` is invoked.
@overload each_nested
  @yieldparam xhtml [String]
@api private
=end
  def each_nested p = self.resource.to_rackful, &block

    # A Resource:
    if p.kind_of?( Resource ) && ! p.equal?( self.resource )
      p.serializer( self.request, self.content_type ).each_nested( &block )

    # A URI:
    elsif p.kind_of?( URI )
      rel_path = p.route_from self.request.content_location
      yield "<a href=\"#{rel_path}\">" +
        Rack::Utils.escape_html( Rack::Utils.unescape( rel_path.to_s ) ) + '</a>'

    # An Object:
    elsif p.respond_to?( :each_pair )
      yield '<br/><dl>'
      p.each_pair do
        |key, value|
        yield '<dt xs:type="xs:string">' +
          Rack::Utils.escape_html( key.to_s.split('_').join(' ') ) +
          "</dt><dd#{self.xsd_type(value)}>"
        self.each_nested value, &block
        yield "</dd>\n"
      end
      yield '</dl>'

    # A List of Objects with identical keys:
    elsif p.kind_of?( Enumerable ) and
          ( q = p.first ) and
          (
            q.respond_to?( :keys ) && ( keys = q.keys ) &&
            p.all? { |r| r.respond_to?( :keys ) && r.keys == keys }
          )
      yield '<table><thead><tr>' +
        keys.collect {
          |column|
          '<th xs:type="xs:string">' +
          Rack::Utils.escape_html( column.to_s.split('_').join(' ') ) +
          "</th>\n"
        }.join + '</tr></thead><tbody>'
      p.each do
        |h|
        yield '<tr>'
        h.each_pair do
          |key, value|
          yield "<td#{self.xsd_type(value)}>"
          self.each_nested value, &block
          yield "</td>\n"
        end
        yield '</tr>'
      end
      yield "</tbody></table>"

    # A List:
    elsif p.kind_of?( Enumerable )
      yield '<ul>'
      p.each do
        |value|
        yield "<li#{self.xsd_type(value)}>"
        self.each_nested value, &block
        yield "</li>\n"
      end
      yield '</ul>'

    # A Time:
    elsif p.kind_of?( Time )
      yield p.utc.xmlschema

    # A Blob:
    elsif p.kind_of?( String ) && p.encoding == Encoding::BINARY
      yield Base64.encode64(p).chomp

    # Something serializable (including nil, true, false, Numeric):
    else
      yield Rack::Utils.escape_html( p.to_s )

    end
  end


=begin markdown
@api private
=end
  def xsd_type v
    if v.respond_to? :to_rackful
      v = v.to_rackful
    end
    if [nil, true, false].include? v
      ' xs:type="xs:boolean" xs:nil="true"'
    elsif v.kind_of? Integer
      ' xs:type="xs:integer"'
    elsif v.kind_of? Numeric
      ' xs:type="xs:decimal"'
    elsif v.kind_of? Time
      ' xs:type="xs:dateTime"'
    elsif v.kind_of?( String ) && v.encoding == Encoding::BINARY
      ' xs:type="xs:base64Binary"'
    elsif v.kind_of?( String )
      ' xs:type="xs:string"'
    else
      ''
    end
  end


end # class Serializer::XHTML


class Serializer::JSON < Serializer


  CONTENT_TYPES = [
    'application/json',
    'application/x-json'
  ]


=begin markdown
@yield [json]
@yieldparam json [String]
=end
  def each thing = self.resource.to_rackful, &block
    if thing.kind_of?( Resource ) && ! thing.equal?( self.resource )
      thing.serializer( self.content_type ).each( &block )
    elsif thing.respond_to? :each_pair
      first = true
      thing.each_pair do
        |k, v|
        yield( ( first ? "{\n" : ",\n" ) + k.to_s.to_json + ":" )
        first = false
        self.each v, &block
      end
      yield( first ? "{}" : "\n}" )
    elsif thing.respond_to? :each
      first = true
      thing.each do
        |v|
        yield( first ? "[\n" : ",\n" )
        first = false
        self.each v, &block
      end
      yield( first ? "[]" : "\n]" )
    elsif thing.kind_of?( String ) && thing.encoding == Encoding::BINARY
      yield Base64.encode64(thing).chomp.to_json
    elsif thing.kind_of?( Time )
      yield thing.utc.xmlschema.to_json
    else
      yield thing.to_json
    end
  end


end # class Serializer::JSON


end # module Rackful
