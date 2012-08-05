require 'rack'
require 'rackful/header_spoofing'
require 'rackful/method_spoofing'
require 'rackful/relative_location'

# The class of the object we're going to serve:
class Root
  include Rackful::Resource
  def initialize *args
    super
    @content = 'Hello world!'
  end
  def do_GET request, response
    response['Content-Type'] = 'text/plain'
    response.write @content
  end
  def do_PUT request, response
    @content = request.body.read
    response.status = status_code :no_content
  end
  def etag
    '"' + Digest::MD5.new.update(@content).to_s + '"'
  end
end
$root_resource = Root.new '/'

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
