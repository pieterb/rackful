=begin License
  Copyright ©2011-2012 Pieter van Beek <pieterb@sara.nl>
  
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at
  
      http://www.apache.org/licenses/LICENSE-2.0
  
  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
=end


require 'rack/request'

module Rackful

=begin markdown
Rack middleware, inspired by {Rack::RelativeRedirect}.

This middleware allows you to return a relative or absolute path your +Location:+
response header.
This was common practice in HTTP/1.0, but HTTP/1.1 requires a full URI in the
+Location:+ header.
This middleware automatically translates your path to a full URI.

Differences with {Rack::RelativeRedirect}:

-   uses Rack::Request::base_url for creating absolute URIs.
-   the `Location:` header, if present, is always rectified, independent of the
    HTTP status code.
=end
class RelativeLocation

  def initialize(app)
    @app = app
  end

  def call(env)
    res = @app.call(env)
    if ( location = res[1]['Location'] ) and
       ! %r{\A[a-z]+://}.match(location)
      request = Rack::Request.new env
      unless '/' == location[0, 1]
        path = request.path.dup
        path[ %r{[^/]*\z} ] = ''
        location = File.expand_path( location, path )
      end
      res[1]['Location'] = request.base_url + location
    end
    res
  end

end # RelativeLocation

end # Rackful