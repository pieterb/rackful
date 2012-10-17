# Required for parsing:

# Required for running:
require 'rack/utils'
require 'uri'
require 'base64'
require 'json'
require 'time'
#require 'json/pure'


module Rackful


=begin markdown
Base class for all serializers.

The default serializers defined in this library ({Rackful::XHTML} and {Rackful::JSON})
depend on the availability of method {Rackful::Resource#to_rackful.}
@abstract Subclasses must implement method `#each` end define constant
  `CONTENT_TYPES`
@since 0.1.0
=end
class Serializer

  include Enumerable

  attr_reader :resource, :content_type

  # @since 0.1.0
  def initialize resource, content_type
    @resource, @content_type = resource, content_type
  end

=begin markdown
Every serializer must implement this method.
@abstract
@since 0.1.0
@yield [data] the entity body 
=end
  def each
    raise HTTP500InternalServerError, "Class #{self.class} doesn't implement #each()."
  end

=begin markdown
@!method headers()
  Extra response headers that a serializer likes to return.

  You don't have to include the `Content-Type` header, as this is done _for_ you.

  This method is optional.
  @return [Hash, nil]
  @abstract
  @since 0.1.0
=end


=begin markdown
@!attribute [r] content_types
  The content types this serializer can produce.
  @return [(String)]
  @abstract
  @since 0.2.0
=end

end # class Serializer


=begin markdown
@since 0.1.0
=end
class XHTML < Serializer

  # The content types served by this serializer.
  # @see Serializer::CONTENT_TYPES
  CONTENT_TYPES = [
    'application/xhtml+xml; charset=UTF-8',
    'text/html; charset=UTF-8',
    'text/xml; charset=UTF-8',
    'application/xml; charset=UTF-8'
  ]


  def each &block
    request = Request.current
    if /xml/ === self.content_type
      yield <<EOS
<?xml version="1.0" encoding="UTF-8"?>
EOS
    end
    yield <<EOS
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:xs="http://www.w3.org/2001/XMLSchema">
<head>
EOS
    unless request.path == request.content_path
      yield <<EOS
<base href="#{request.base_path.relative request.path}"/>
EOS
    end
    unless '/' == request.path
      yield <<EOS
<link rel="contents" href="#{'/' === request.content_path[-1] ? '../' : './' }"/>
EOS
    end
    yield header + '<div id="rackful_content">'
    each_nested &block
    yield '</div>' + footer
  end

  # Look at the source code!
  def header
    "<title>#{ Rack::Utils.escape_html(resource.title) }</title></head><body>"
  end

  # Look at the source code!
  def footer
    '<div class="rackful_powered">Powered by <a href="http://github.com/pieterb/Rackful">Rackful</a></div></body></html>'
  end

  # Serialize almost any kind of Ruby object to XHTML.
  def each_nested p = self.resource.to_rackful, &block
  
    if p.kind_of?( Path )
      yield "<a href=\"#{p.relative}\">" +
        Rack::Utils.escape_html( Rack::Utils.unescape(
          File::basename(p.unslashify)
        ) ) + '</a>'
        
    elsif p.kind_of?( Resource ) && ! p.equal?( self.resource )
      p.serializer( self.content_type ).each_nested &block
      
    elsif p.kind_of?( Enumerable ) and p.respond_to?( :each_pair ) and
          p.all? { |r, s| r.kind_of?( Path ) }
      yield '<dl class="rackful-resources">'
      p.each_pair do
        |path, child|
        yield '<dt>'
        self.each_nested path, &block
        yield "</dt><dd#{self.xsd_type(child)}>"
        self.each_nested child, &block
        yield "</dd>\n"
      end
      yield '</dl>'
      
    elsif p.respond_to?( :each_pair )
      yield '<dl class="rackful-object">'
      p.each_pair do
        |path, child|
        yield '<dt>'
        self.each_nested path, &block
        yield "</dt><dd#{self.xsd_type(child)}>"
        self.each_nested child, &block
        yield "</dd>\n"
      end
      yield '</dl>'
      
    elsif p.kind_of?( Enumerable ) and ( q = p.first ) and (
            q.respond_to?(:keys) && ( keys = q.keys ) &&
            p.all? { |r| r.respond_to?(:keys) && r.keys == keys }
          )
      yield '<table class="rackful-objects"><thead><tr>' +
        keys.collect {
          |column|
          '<th>' +
          Rack::Utils.escape_html( column.to_s.split('_').join(' ') ) +
          "</th>\n"
        }.join + '</tr></thead><tbody>'
      p.each do
        |h|
        yield '<tr>'
        h.each_pair do
          |key, value|
          yield "<td class=\"rackful-objects-#{Rack::Utils.escape_html( key.to_s )}\"#{self.xsd_type(value)}>"
          self.each_nested value, &block
          yield "</td>\n"
        end
        yield '</tr>'
      end
      yield "</tbody></table>"
      
    elsif p.kind_of?( Enumerable )
      yield '<ul class="rackful-array">'
      p.each do
        |value|
        yield "<li#{self.xsd_type(value)}>"
        self.each_nested value, &block
        yield "</li>\n"
      end
      yield '</ul>'
      
    elsif p.kind_of?( Time )
      yield p.utc.xmlschema
      
    elsif p.kind_of?( String ) && p.encoding == Encoding::BINARY
      yield Base64.encode64(p).chomp
      
    else
      yield Rack::Utils.escape_html( p.to_s )
      
    end
  end


  # @private
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
    elsif v.kind_of?( String ) && !v.kind_of?( Path )
      ' xs:type="xs:string"'
    else
      ''
    end
  end


end # class XHTML


class JSON < Serializer


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
      thing.serializer( self.content_type ).each &block
    elsif thing.kind_of?( Rackful::Path )
      yield thing.relative
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


  def self.parse input
    r = ::JSON.parse(
      input.read,
      :symbolize_names => true
    )
    self.recursive_datetime_parser r
  end

  def self.recursive_datetime_parser p
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


end # class HTTPStatus::JSON

end # module Rackful
