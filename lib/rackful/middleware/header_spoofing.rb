# Copyright ©2011-2012 Pieter van Beek <pieter@djinnit.com>
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
Rack middleware that provides header spoofing.

If you use this middleware, then clients are allowed to spoof an HTTP header
by specifying a `_http_SOME_HEADER=...` request parameter, for example:

    http://example.com/some_resource?_http_DEPTH=infinity

This can be useful if you want to specify certain request headers from within
a normal web browser.
@example Using this middleware
  use Rackful::HeaderSpoofing
=end
class Rackful::HeaderSpoofing

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
  original_query_string = env['QUERY_STRING']
  env['QUERY_STRING'] = original_query_string.
    split('&', -1).
    collect { |s| s.split('=', -1) }.
    select {
      |p|
      if  /\A_http_([a-z]+(?:[\-_][a-z]+)*)\z/i === p[0]
        header_name = p.shift.gsub('-', '_').upcase[1..-1]
        env[header_name] = p.join('=')
        false
      else
        true
      end
    }.
    collect { |p| p.join('=') }.
    join('&')
  if original_query_string != env['QUERY_STRING']
    env['rackful.header_spoofing.query_string'] ||= original_query_string
  end
end

def after_call env
  #if original_query_string = env['rackful.header_spoofing.query_string']
    #env['rackful.header_spoofing.query_string'] = env['QUERY_STRING']
    #env['QUERY_STRING'] = original_query_string
  #end
end

end # Rackful::HeaderSpoofing
