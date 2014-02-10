# encoding: utf-8
# Required for parsing:
require 'rackful'

# Required for running:
require 'set'


# Middleware that provides method spoofing, like {Rack::MethodOverride}.
#
# If you use this middleware, then clients are allowed to spoof an HTTP method
# by specifying a `_method=...` request parameter, for example
# `http://example.com/some_resource?_method=DELETE`.
#
# This can be useful if you want to perform `PUT` and `DELETE` requests from
# within a browser, of when you want to perform a `GET` requests with (too)
# many parameters, exceeding the maximum URI length in your client or server.
# In that case, you can put the parameters in a `POST` body, like this:
#
#     POST /some_resource HTTP/1.1
#     Host: example.com
#     Content-Type: application/x-www-form-urlencoded
#     Content-Length: 123456789
#      
#     param_1=hello&param_2=world&param_3=...
#
# Caveats:
#
# *   this middleware won’t work well together with Digest Authentication.
# *   When a `POST` request is converted to a `GET` request, the entire request
#     body is loaded into memory, which creates an attack surface for
#     DoS-attacks. Hence, the maximum request body size is limited (see
#     {DEFAULT_QUERY_STRING_MAX_LENGTH} and {#initialize}). You should choose this
#     limit carefully, and/or include this middleware *after* your security
#     middlewares.
#
# Improvements over Rack::MethodOverride (v1.5.2):
#
# *   Rack::MethodOverride requires the original method to be `POST`. We allow
#     the following overrides (`ORIGINAL_METHOD` → `OVERRIDE_WITH`):
#     *   `GET` → `DELETE`, `HEAD` and `OPTIONS`
#     *   `POST` → `GET`, `PATCH` and `PUT`
# *   Rack::MethodOverride doesn’t touch `env['QUERY_STRING']`. We remove
#     parameter `_method` if it was handled (but still leave it there if it
#     wasn’t handled for some reason).
# *   Rackful::MethodOverride is documented ;-)
# @example Using this middleware
#   require 'rackful/middleware/method_override'
#   use Rackful::MethodOverride
class Rackful::MethodOverride

  METHOD_OVERRIDE_PARAM_KEY = '_method'.freeze

  # The maximum size of a `POST` request body to be converted into `GET`
  # query parameters.
  DEFAULT_QUERY_STRING_MAX_LENGTH = 1024 * 1024

  ALLOWED_OVERRIDES = {
    'GET'.freeze  => [ 'DELETE', 'HEAD',  'OPTIONS' ].to_set.freeze,
    'POST'.freeze => [ 'PATCH', 'PUT'     ].to_set.freeze
  }.freeze

  # Constructor. Supported options are:
  #
  # *   **`:max_length`** the maximum accepted request body size (in bytes) for
  #     `POST` → `GET` method overrides.
  # @example config.ru
  #   use Rackful::MethodOverride, :max_length => 2**26 # 64MiB
  def initialize( app, options = {} )
    @app = app
    @max_length = options[:max_length].to_i || DEFAULT_QUERY_STRING_MAX_LENGTH
  end


  def call env
    before_call env
    @app.call env
  end

  private


  def before_call env
    return unless ['GET', 'POST'].include? env['REQUEST_METHOD']
    new_method = nil
    new_query_string = env['QUERY_STRING'].
    split('&', -1).
    select { |p|
      p = p.split('=', 2)
      if new_method.nil? && METHOD_OVERRIDE_PARAM_KEY == p[0]
        new_method = p[1].upcase
        false
      else
        true
      end
    }.
    join('&')
    if new_method
      if  'GET' == new_method &&
          'POST' == env['REQUEST_METHOD'] &&
          'application/x-www-form-urlencoded' == env['CONTENT_TYPE'] &&
          env['CONTENT_LENGTH'].to_i <= @max_length
        if env.key?('rack.input')
          new_query_string += '&' unless new_query_string.empty?
          new_query_string += env['rack.input'].read
          if  env['rack.input'].respond_to?( :rewind )
              env['rack.input'].rewind
              env['rackful.method_override.input'] = env['rack.input']
          end
          env.delete 'rack.input'
        end
        env.delete 'CONTENT_TYPE'
        env.delete 'CONTENT_LENGTH'
        update_env( env, new_method, new_query_string )
      elsif ALLOWED_OVERRIDES[env['REQUEST_METHOD']].include?( new_method )
        update_env( env, new_method )
      elsif logger = env['rack.logger']
        logger.warn('Rackful::MethodOverride') {
          "Client tried to override request method #{env['REQUEST_METHOD']} with #{new_method} (ignored)."
        }
      else
        STDERR << "warning: Client tried to override request method #{env['REQUEST_METHOD']} with #{new_method} (ignored).\n"
      end
    end
  end


  def update_env env, new_method, new_query_string = nil
    unless new_query_string.nil?
      env['rackful.method_override.QUERY_STRING'] = env['QUERY_STRING']
      env['QUERY_STRING'] = new_query_string
    end
    env['rackful.method_override.REQUEST_METHOD'] = env['REQUEST_METHOD']
    env['REQUEST_METHOD'] = new_method
  end

end # Rackful::MethodOverride
