# encoding: utf-8


=begin deprecated
  =begin markdown
  A String monkeypatch
  =end
  class String


  =begin markdown
  @return [Rackful::Path]
  =end
    def to_path
      Rackful::Path.new( self )
    end


  end # class String
=end


class URI::Generic


  alias_method :rackful_normalize!, :normalize!


=begin markdown
Canonicalizes the path.
No unreserved characters are pct-encoded, and all non-unreserved characters _are_
pct-encoded.

Check RFC3986 syntax:
  abempty = *( "/" *(unreserved / pct-encoded / sub-delims / ":" / "@") )
  unreserved = ALPHA / DIGIT / "-" / "." / "_" / "~"
  sub-delims = "!" / "$" / "&" / "'" / "(" / ")" / "*" / "+" / "," / ";" / "="
@return [self, nil] self if the path was modified, or nil of the path was
  already in canonical form.
=end
  def normalize!
    #unless %r{\A(?:/(?:[a-z0-9\-._~!$&'()*+,;=:@]|%[0-9a-f]{2})*)*\z}i === self.path
    #  raise TypeError, "Can’t convert String #{self.path.inspect} to Rackful::Path"
    #end
    self.rackful_normalize!
    path = '/' + self.segments( Encoding::BINARY ).collect do |segment|
      segment.gsub(/([^a-zA-Z0-9\-._~]+)/n) {
        '%'+$1.unpack('H2'*bytesize($1)).join('%').upcase
      }
    end.join('/')
    if path == self.path
      nil
    else
      self.path = path
      self
    end
  end


=begin markdown
@return [Path] a copy of `self`, with a trailing slash.
=end
  def slashify
    r = self.dup
    r.slashify!
    r
  end


=begin markdown
Adds a trailing slash to `self` if necessary.
@return [self]
=end
  def slashify!
    if '/' != self.path[-1,1]
      self.path += '/'
      self
    else
      nil
    end
  end


=begin markdown
@return [Path]a copy of `self` without trailing slashes.
=end
  def unslashify
    r = self.dup
    r.unslashify!
    r
  end


=begin markdown
Removes trailing slashes from `self`.
@return [self]
=end
  def unslashify!
    path = self.path.sub( %r{/+\z}, '' )
    if path == self.path
      nil
    else
      self.path = path
      self
    end
  end


=begin markdown
@return [Array<String>] Unencoded segments
=end
  def segments( encoding = Encoding::UTF_8 )
    r = self.path.split(%r{/+}).collect do |s|
      Rack::Utils.unescape( s, encoding )
    end
    r.shift
    r
  end


=begin markdown
Turns a relative URI (starting with `/`) into a relative path (starting with `./` or `../`)
@param base_path [Path]
@return [String] a relative URI
@deprecated
=end
  def relative_deprecated base_path
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


end # class URI::Generic
