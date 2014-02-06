# encoding: utf-8


module Rackful::WebDAV::Parser


class PROPFIND < Rackful::Parser::DOM


=begin markdown
@return [nil, Array<String>] with the following meaning:
  * `nil` indicates an `propname` request;
  * `[]` (an empty Array) indicates an `allprop` request;
  * `[ prop, ... ]` indicates a request for certain properties.
=end
  def parse
    return nil if self.document.xpath(
      '/D:propfind/D:allprop',
      'D' => 'DAV:'
    ).length == 1
    return [] if self.document.xpath(
      '/D:propfind/D:propname',
      'D' => 'DAV:'
    ).length == 1
    props = self.document.xpath(
      '/D:propfind/D:prop/*',
      'D' => 'DAV:'
    )
    if props.length < 1
      raise HTTP400BadRequest,
        'Couldn’t parse:<br/>' + Rack::Utils.escape_html(self.document.to_xml)
    end
    props.collect do |node|
      node.namespace.href + ' ' + node.name
    end
  end


end # class PROPFIND


class PROPPATCH < Rackful::Parser::DOM


=begin markdown
Parses the body of a PROPPATCH request.
=end
  def parse
    r = { :set => {}, :remove => [] }
    self.document.xpath(
      '/D:propertyupdate/D:set/D:prop/*', 'D' => 'DAV:'
    ).each do |property|
      property_name = ( property.namespace ? property.namespace.href : '' ) + ' ' + property.node_name
      r[:set][property_name] = property
    end
    self.document.xpath(
      '/D:propertyupdate/D:remove/D:prop/*', 'D' => 'DAV:'
    ).each do |property|
      property_name = ( property.namespace ? property.namespace.href : '' ) + ' ' + property.node_name
      r[:remove] << property_name
    end
    r
  end


end # class PROPFIND


end # module Rackful::WebDAV::Parser
