require 'nokogiri'

doc = Nokogiri::XML::Document.parse(
'<?xml version="1.0" encoding="UTF-8" ?>
<D:propertyupdate xmlns:D="DAV:" xmlns:Z="http://ns.example.com/standards/z39.51/" xmlns="http://www.sara.nl">
  <D:set>
    <D:prop>
      <Z:Authors>
        <Z:Author>Jim Whitehead</Z:Author>
        <Z:Author>Roy Fielding</Z:Author>
      </Z:Authors>
      <D:getcontentlength>
        <something/>
      </D:getcontentlength>
    </D:prop>
  </D:set>
  <D:remove>
    <D:prop><Z:Copyright-Owner/></D:prop>
  </D:remove>
</D:propertyupdate>'
)

doc2 = Nokogiri::XML::Document.parse(
'<?xml version="1.0" encoding="UTF-8" ?>
<D:propertyupdate xmlns:D="DAV:" xmlns:Z="http://ns.example.com/standards/z39.51/">
  <D:set>
    <D:prop>
      <Z:Authors>
        <Z:Author>Jim Whitehead</Z:Author>
        <Z:Author>Roy Fielding</Z:Author>
      </Z:Authors>
      <getcontentlength>
        <something/>
      </getcontentlength>
    </D:prop>
  </D:set>
  <D:remove>
    <D:prop><Z:Copyright-Owner/></D:prop>
  </D:remove>
</D:propertyupdate>'
)

target = doc.at_xpath(
  '/D:propertyupdate/D:set/D:prop', 'D' => 'DAV:'
)

newdoc = Nokogiri::XML::Document.new
doc2.xpath(
  '/D:propertyupdate/D:set/D:prop/*', 'D' => 'DAV:'
).each do |prop|
  newdoc.root = prop
  unless newdoc.root.namespace
    newdoc.root.add_namespace( nil, '' )
  end
  puts newdoc.root.to_xml
  target.add_child newdoc.root.to_xml
  # doc2 = 
  # doc2.root = prop
  # puts doc2.root.to_xml
  # puts
end

puts doc.to_xml
