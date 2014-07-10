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
    response['Content-Type'] = 'text/plain; charset="UTF-8"'
  end
end


# The class of the object we're going to serve:
class MyRepresentable
  include Rackful::Representable
  add_serializer Rackful::Serializer::HALJSON
  add_parser Rackful::Parser::HALJSON

  def self.collection_hallink
    @collection_hallink ||= Rackful::HALLink.new('/representables/', MyRepresentableCollection.instance)
  end

  attr_reader :last_modified, :hal_properties


  def hal_links
    retval = @hal_links.dup
    retval[:collection] = self.class.collection_hallink
    retval
  end


  def initialize uri
    self.uri = uri
    @hal_properties = {
      :a => 'Hello',
      :b => Time.now,
    }
    @hal_links = { :example => Rackful::HALLink('http://www.example.com/some/path') }
    @last_modified = [ Time.now, false ]
  end


  def do_PUT request, response
    parser = self.parser(request)
    @hal_properties = parser.hal_properties
    @hal_links = parser.hal_links
    @hal_links.delete :self
    @last_modified = [ Time.now, false ]
  end


  def etag
    '"' + Digest::MD5.new.update(hal_properties.inspect).to_s + '"'
  end
end


class MyRepresentableCollection
  include Rackful::Representable
  add_serializer Rackful::Serializer::HALJSON
  add_parser Rackful::Parser::HALJSON

  def self.instance
    @instance ||= self.new
  end


  def initialize
    self.uri = '/representables/'
    @representables = {}
  end
  attr_reader :representables
  def representable x
    self.representables[x] ||= MyRepresentable.new(self.uri.to_s + x)
  end
  def hal_links
    { :item => self.representables.values.map { |r| HALLink.new(r.uri, r) } }
  end

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
    when %r{^/representables/?$}
      MyRepresentableCollection.new(uri.slashify.path)
    when %r{^/representables/(.+)$}
      MyRepresentableCollection.instance.representable $1
    end
  }

end.to_app


require 'rack/test'


module AppHelper

  def app
    $current_app ||= $APP1
  end


  def app= app
    $current_app = app
  end
end


World(Rack::Test::Methods, AppHelper)
