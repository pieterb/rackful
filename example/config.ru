# encoding: utf-8

$LOAD_PATH << File.expand_path( File.join( '..', 'lib' ), File.dirname( File.expand_path( __FILE__ ) ) )

# Load core functionality:
require 'rackful'


# Load extra middlewares {Rackful::MethodOverride MethodOverride} and {Rackful::HeaderSpoofing HeaderSpoofing}:
require 'rackful/middleware'


# Used below for calculating ETags:
require 'digest/md5'


# The class of the object we're going to serve:
class MyResource
  include Rackful::Representable

  attr_reader :last_modified, :hal_properties, :hal_links

  def initialize
    @hal_properties = {
      :a => 'Hello',
      :b => Time.now,
    }
    @hal_links = { :example => Rackful::HALLink('http://www.example.com/some/path') }
    @last_modified = [ Time.now, false ]
  end


  def do_PUT request, response
    @hal_properties = parser(request).to_rackful
    @last_modified = [ Time.now, false ]
  end


  def etag
    '"' + Digest::MD5.new.update(hal_properties.inspect).to_s + '"'
  end
  add_serializer Rackful::Serializer::HALJSON
  add_parser Rackful::Parser::HALJSON
end


$hello_world = MyResource.new
$hello_world.uri = '/hello_world'

use Rack::Reloader
use Rackful::MethodOverride
use Rackful::HeaderSpoofing
run Rackful::Server.new {
  |uri|
  $hello_world
  #'/hello_world' === uri.path ? $hello_world : nil
}
