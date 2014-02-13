# Extension and monkeypatch of Ruby’s StdLib URI::Generic class.
class URI::Generic

  unless method_defined? :uri_generic_normalize!
    # Copy of the original StdLib
    # [URI::Generic::normalize!](http://ruby-doc.org/stdlib/libdoc/uri/rdoc/URI/Generic.html#method-i-normalize-21)
    # method.
    alias_method :uri_generic_normalize!, :normalize!
  end
  
  unless method_defined? :uri_generic_normalize
    # Copy of the original StdLib
    # [URI::Generic::normalize!](http://ruby-doc.org/stdlib/libdoc/uri/rdoc/URI/Generic.html#method-i-normalize-21)
    # method.
    alias_method :uri_generic_normalize, :normalize
  end
  
  # (see #normalize!)
  # @return [URI::Generic] a normalized copy of `self`.
  def normalize
    r = self.dup
    r.normalize!
    r
  end

  # Monkeypatch of [Ruby’s StdLib implementation](http://ruby-doc.org/stdlib/libdoc/uri/rdoc/URI/Generic.html#method-i-normalize-21).
  # In addition to the default implementation, this implementation ensures that
  #
  # 1.  _no_ unreserved characters are pct-encoded, and
  # 2.  all non-unreserved characters _are_ pct-encoded.
  #
  # Check [RFC3986](http://tools.ietf.org/html/rfc3986) syntax:
  #
  #     abempty = *( "/" *(unreserved / pct-encoded / sub-delims / ":" / "@") )
  #     unreserved = ALPHA / DIGIT / "-" / "." / "_" / "~"
  #     sub-delims = "!" / "$" / "&" / "'" / "(" / ")" / "*" / "+" / "," / ";" / "="
  # @return [self, nil] `self` if the URI was modified, or `nil` of the uri was
  #   already in normal form.
  def normalize!
    #unless %r{\A(?:/(?:[a-z0-9\-._~!$&'()*+,;=:@]|%[0-9a-f]{2})*)*\z}i === self.path
    #  raise TypeError, "Can’t convert String #{self.path.inspect} to Rackful::Path"
    #end
    self.uri_generic_normalize!
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


  # @return [Path] a copy of `self`, with a trailing slash.
  def slashify
    r = self.dup
    r.slashify!
    r
  end


  # Adds a trailing slash to `self` if necessary.
  # @return [self]
  def slashify!
    if '/' != self.path[-1,1]
      self.path += '/'
      self
    else
      nil
    end
  end


  # @return [Path] a copy of `self` without trailing slashes.
  def unslashify
    r = self.dup
    r.unslashify!
    r
  end


  # Removes trailing slashes from `self`.
  # @return [self]
  def unslashify!
    path = self.path.sub( %r{/+\z}, '' )
    if path == self.path
      nil
    else
      self.path = path
      self
    end
  end


  # @return [Array<String>] Unencoded segments
  def segments( encoding = Encoding::UTF_8 )
    r = self.path.split(%r{/+}).collect do |s|
      Rack::Utils.unescape( s, encoding )
    end
    r.shift
    r
  end


  # Turns a relative URI (starting with `/`) into a relative path (starting with `./` or `../`)
  # @param base_path [Path]
  # @return [String] a relative URI
  # @deprecated
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
