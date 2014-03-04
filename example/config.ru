# Load core functionality:
require 'rackful'


# Load extra middlewares: ({Rackful::MethodOverride}, {Rackful::HeaderSpoofing})
require 'rackful/middleware'
require 'digest/md5'


# The class of the object we're going to serve:
class MyResource
  include Rackful::Resource
  attr_accessor :to_rackful

  def initialize
    self.uri = '/hello_world'
    @to_rackful = {
      :a => 'Hello',
      :b => Time.now,
      :c => URI('http://www.example.com/some/path')
    }
  end

  def get_etag
    '"' + Digest::MD5.new.update(to_rackful.inspect).to_s + '"'
  end
  add_serializer Rackful::Serializer::XHTML, 1.0
  add_serializer Rackful::Serializer::JSON, 0.5
  add_parser Rackful::Parser::XHTML
  add_parser Rackful::Parser::JSON
end

use Rack::Reloader
use Rackful::MethodOverride
use Rackful::HeaderSpoofing

run Rackful::Server.new { |uri|
  $root_resource ||= MyResource.new
}