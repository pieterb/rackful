# Load core functionality:
require 'rackful'

# Load extra middlewares: ({Rackful::MethodSpoofing}, {Rackful::HeaderSpoofing})
require 'rackful/middleware'

require 'digest/md5'

# The class of the object we're going to serve:
class Root
  include Rackful::Resource
  attr_reader :to_rackful
  def initialize path
    self.relative_url = path
    @to_rackful = { :a => 'Hello', :b => Time.now }
  end
  def do_PUT request, response
    @to_rackful = self.parser(request).parse
  end
  def get_etag
    '"' + Digest::MD5.new.update(to_rackful.inspect).to_s + '"'
  end
  add_serializer Rackful::Serializer::XHTML, 1.0
  add_serializer Rackful::Serializer::JSON, 0.5
  add_parser Rackful::Parser::XHTML
  add_parser Rackful::Parser::JSON
end
$root_resource = nil

# Rackful::Server needs a resource factory which can map URIs to resource objects:
class ResourceFactory
  include Rackful::ResourceFactory
  def [] path
    case path
    when '/' then $root_resource ||= Root.new(path)
    else raise Rackful::HTTP404NotFound
    end
  end
end

use Rack::Reloader
use Rackful::MethodSpoofing
use Rackful::HeaderSpoofing

run Rackful::Server.new ResourceFactory.new
