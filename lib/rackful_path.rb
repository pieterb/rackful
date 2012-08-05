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

end # class Path


end # module Rackful

=begin comment
# Monkeypatch to this stdlib class.
class URI::Generic

  # @see http://www.w3.org/TR/html401/struct/links.html#adef-rel the HTML `rel` attribute.
  attr_accessor :rel

  # @see http://www.w3.org/TR/html401/struct/links.html#adef-rev the HTML `rev` attribute.
  attr_accessor :rev

  def to_xhtml base_path, encoding = Encoding::UTF_8
    retval = "<a href=\"#{self.route_from(base_path)}\"".encode encoding
    retval << " rel=\"#{self.rel}\"" if self.rel
    retval << " rev=\"#{self.rev}\"" if self.rev
    retval << '>'
    if self.relative? && ! self.query && ! self.fragment
      retval << Rack::Utils.escape_html(
                  Rack::Utils.unescape( self.route_from(base_path).to_s, encoding )
                )
    else
      retval << self.to_s
    end
    retval << '</a>'
    retval
  end

  # @return [URI::Generic]
  def slashify
    r = self.dup
    r.path = r.path.unslashify
    r
  end

  # @return [self, nil]
  def slashify!
    self.path.slashify! && self
  end

  # @return [URI::Generic]
  def unslashify
    r = self.dup
    r.path = r.path.unslashify
    r
  end

  # @return [self, nil]
  def unslashify!
    self.path.unslashify! && self
  end

end # class ::URI::Generic
=end comment



