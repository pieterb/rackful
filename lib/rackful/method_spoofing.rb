# Copyright ©2011-2012 Pieter van Beek <pieterb@sara.nl>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'rackful'

=begin markdown
Rack middleware that provides method spoofing.

If you use this middleware, then clients are allowed to spoof an HTTP method
by specifying a `_method=...` request parameter, for example:

    http://example.com/some_resource?_method=DELETE

This can be useful if you want to perform `PUT` and `DELETE` requests from
within a browser, of when you want to perform a `GET` requests with (too)
many parameters, exceeding the maximum URI length in your client or server.
In that case, you can put the parameters in a `POST` body, like this:

    POST /some_resource HTTP/1.1
    Host: example.com
    Content-Type: application/x-www-form-urlencoded
    Content-Length: 123456789

    param_1=hello&param_2=world&param_3=...
@example Using this middleware
  use Rackful::MethodSpoofing
@since 0.0.1
=end
class Rackful::MethodSpoofing

def initialize app
  @app = app
end

def call env
  before_call env
  r = @app.call env
  after_call env
  r
end

def before_call env
  return unless ['GET', 'POST'].include? env['REQUEST_METHOD']
  original_query_string = env['QUERY_STRING']
  new_method = nil
  env['QUERY_STRING'] = original_query_string.
    split('&', -1).
    collect { |s| s.split('=', -1) }.
    select {
      |p|
      if  /_method/i   === p[0] &&
          /\A[A-Z]+\z/ === ( method = p[1..-1].join('=').upcase ) &&
          ! new_method
        new_method = method
        false
      else
        true
      end
    }.
    collect { |p| p.join('=') }.
    join('&')
  if new_method
    if  'GET' == new_method &&
        'POST' == env['REQUEST_METHOD'] &&
        'application/x-www-form-urlencoded' == env['CONTENT_TYPE']
      unless env['QUERY_STRING'].empty
        env['QUERY_STRING'] = env['QUERY_STRING'] + '&'
      end
      begin
        env['QUERY_STRING'] = env['QUERY_STRING'] + env['rack.input'].read
        env['rack.input'].rewind
      end
      env['rackful.method_spoofing.input'] = env['rack.input']
      env.delete 'rack.input'
      env.delete 'CONTENT_TYPE'
      env.delete 'CONTENT_LENGTH' if env.key? 'CONTENT_LENGTH'
    end
    env['rackful.method_spoofing.QUERY_STRING'] ||= original_query_string
    env['rackful.method_spoofing.REQUEST_METHOD'] = env['REQUEST_METHOD']
    env['REQUEST_METHOD'] = new_method
  end
end

def after_call env
  if env.key? 'rackful.method_spoofing.input'
    env['rack.input'] = env['rackful.method_spoofing.input']
    env.delete 'rackful.method_spoofing.input'
  end
end

end # Rackful::MethodSpoofing
