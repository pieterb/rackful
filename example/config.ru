# Load core functionality:
require 'rackful'


# Load extra middlewares: ({Rackful::MethodOverride}, {Rackful::HeaderSpoofing})
require 'rackful/middleware'
require 'digest/md5'


# The class of the object we're going to serve:
class Root
  include Rackful::Resource
  attr_reader :to_rackful

  def initialize uri
    super( uri )
    @to_rackful = {
      :a => 'Hello',
      :b => Time.now,
      :c => URI('http://www.example.com/some/path')
    }
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

use Rack::Reloader
use Rackful::MethodOverride
use Rackful::HeaderSpoofing

run Rackful::Server.new { |uri|
  $root_resource ||= Root.new( 'http://localhost:9292/hallo_wereld' )
}
