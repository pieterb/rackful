# encoding: utf-8

$LOAD_PATH << File.expand_path( File.join( '..', '..', 'lib' ), File.dirname( File.expand_path( __FILE__ ) ) )

# Load core functionality:
require 'rackful'


# Load extra middlewares {Rackful::MethodOverride MethodOverride} and {Rackful::HeaderSpoofing HeaderSpoofing}:
require 'rackful/middleware'


# Used below for calculating ETags:
require 'digest/md5'


# The class of the object we’re going to serve:
class Greeter
  include Rackful::Resource

  def initialize uri
    self.uri = uri
  end


  def do_GET(request, response)
    response.body << 'Hello world!'
    response['Content-Type'] = 'text/plain; charset="utf-8"'
  end
end


# The class of the object we're going to serve:
class MyRepresentable
  include Rackful::Resource
  include Rackful::Serializable

  attr_reader :to_rackful, :get_last_modified

  def initialize uri
    self.uri = uri
    @to_rackful = {
      :a => 'Hello',
      :b => Time.now,
      :c => URI('http://www.example.com/some/path')
    }
    @get_last_modified = [ Time.now, false ]
  end


  def do_PUT request, response
    @to_rackful = parser(request).to_rackful
    @get_last_modified = [ Time.now, false ]
  end


  def get_etag
    '"' + Digest::MD5.new.update(to_rackful.inspect).to_s + '"'
  end
  add_representation Rackful::Representation::XHTML5
  add_representation Rackful::Representation::HTML5, :quality => 0.9
  add_representation Rackful::Representation::JSON,  :quality => 0.5
  add_parser Rackful::Parser::XHTML5
  add_parser Rackful::Parser::JSON
end


$APP1 = Rack::Builder.new do

  use Rackful::HeaderSpoofing
  use Rackful::MethodOverride

  $app1_cache = {}
  run Rackful::Server.new {
    |uri|
    $app1_cache[uri.path] ||= case uri.path
    when '/greeter'
      Greeter.new(uri.path)
    end
  }

end.to_app


require 'rack/test'


module App1Helper

  def app
    $APP1
  end
end


World(Rack::Test::Methods, App1Helper)
