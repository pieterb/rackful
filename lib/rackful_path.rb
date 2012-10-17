# Required for parsing:

# Required for running:
require 'rack/utils'


# A String monkeypatch
# @private
class String

  def to_path; Rackful::Path.new(self); end

end


module Rackful


# Relative URI (a path)
class Path < String

  def slashify
    r = self.dup
    r << '/' if '/' != r[-1,1]
    r
  end

  def slashify!
    if '/' != self[-1,1]
      self << '/'
    else
      nil
    end
  end

  def unslashify
    r = self.dup
    r = r.chomp( '/' ) if '/' == r[-1,1]
    r
  end

  def unslashify!
    if '/' == self[-1,1]
      self.chomp! '/'
    else
      nil
    end
  end

  # An alias for Rack::Utils.unescape
  def unescape( encoding = Encoding::UTF_8 ); Rack::Utils.unescape(self, encoding); end
  

  # @return [Array<String>] An array of unencoded segments
  def segments
    r = self.split('/').collect { |s| Rack::Utils.unescape( s, Encoding::UTF_8 ) }
    r.shift
    r
  end


  # Turns a relative URI (starting with `/`) into a relative path (starting with `./`)
  # @param path [Path]
  # @return [String]
  # @since 0.1.0
  def relative base_path = nil
    begin
      base_path ||= Request.current.base_path
    rescue
      return self.dup
    end
    case self
    when base_path
      # RFC2396, Section 4.2
      return ''
    when %r{(?:\A|/)\.\.?(?:/|\z)}
      # self has abnormal absolute path,
      # like "/./", "/../", "/x/../", ...
      return self.dup
    end

    src_path = base_path.scan(%r{(?:\A|[^/]+)/})
    dst_path = self.scan(%r{(?:\A|[^/]+)/?})

    # discard same parts
    while !dst_path.empty? && dst_path.first == src_path.first
      src_path.shift
      dst_path.shift
    end

    tmp = dst_path.join

    # calculate
    if src_path.empty?
      if tmp.empty?
        return './'
      elsif dst_path.first.include?(':') # (see RFC2396 Section 5)
        return './' + tmp
      else
        return tmp
      end
    end

    return '../' * src_path.size + tmp
  end


end # class Path


end # module Rackful


#~ # Monkeypatch to this stdlib class.
#~ class URI::Generic
#~ 
  #~ # @see http://www.w3.org/TR/html401/struct/links.html#adef-rel the HTML `rel` attribute.
  #~ attr_accessor :rel
#~ 
  #~ # @see http://www.w3.org/TR/html401/struct/links.html#adef-rev the HTML `rev` attribute.
  #~ attr_accessor :rev
#~ 
  #~ def to_xhtml base_path, encoding = Encoding::UTF_8
    #~ retval = "<a href=\"#{self.route_from(base_path)}\"".encode encoding
    #~ retval << " rel=\"#{self.rel}\"" if self.rel
    #~ retval << " rev=\"#{self.rev}\"" if self.rev
    #~ retval << '>'
    #~ if self.relative? && ! self.query && ! self.fragment
      #~ retval << Rack::Utils.escape_html(
                  #~ Rack::Utils.unescape( self.route_from(base_path).to_s, encoding )
                #~ )
    #~ else
      #~ retval << self.to_s
    #~ end
    #~ retval << '</a>'
    #~ retval
  #~ end
#~ 
  #~ # @return [URI::Generic]
  #~ def slashify
    #~ r = self.dup
    #~ r.path = r.path.unslashify
    #~ r
  #~ end
#~ 
  #~ # @return [self, nil]
  #~ def slashify!
    #~ self.path.slashify! && self
  #~ end
#~ 
  #~ # @return [URI::Generic]
  #~ def unslashify
    #~ r = self.dup
    #~ r.path = r.path.unslashify
    #~ r
  #~ end
#~ 
  #~ # @return [self, nil]
  #~ def unslashify!
    #~ self.path.unslashify! && self
  #~ end
#~ 
#~ end # class ::URI::Generic



