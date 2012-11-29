# Load core functionality:
require 'rackful'

# Load extra middlewares: ({Rackful::MethodSpoofing}, {Rackful::HeaderSpoofing},
# Rackful::RelativeLocation})
require 'rackful/middleware'

require 'digest/md5'

# The class of the object we're going to serve:
class Root
  include Rackful::Resource
  attr_reader :to_rackful
  def initialize
    self.path = '/'
    @to_rackful = 'Hello world!'
  end
  def do_PUT request, response
    @to_rackful = request.body.read.encode( Encoding::UTF_8 )
  end
  def get_etag
    '"' + Digest::MD5.new.update(to_rackful).to_s + '"'
  end
  add_serializer Rackful::XHTML, 1.0
  add_serializer Rackful::JSON, 1.0
  add_media_type 'text/plain'
end
$root_resource = Root.new

# Rackful::Server needs a resource factory which can map URIs to resource objects:
class ResourceFactory
  def [] uri
    case uri
    when '/';   $root_resource
    else;       nil
    end
  end
end

use Rackful::MethodSpoofing
use Rackful::HeaderSpoofing
use Rackful::RelativeLocation

run Rackful::Server.new ResourceFactory.new
