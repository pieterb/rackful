# encoding: utf-8

# Internal “core” files, in alphabetic order and excluding `rackful/global.rb`:
#require_relative 'rackful/parser.rb' # Superseded by Representation
require_relative 'rackful/request.rb'
require_relative 'rackful/server.rb'
require_relative 'rackful/statuscodes.rb'

# Inclusion tree:
# rackful.rb
# |- request.rb
# |- server.rb
# `- statuscodes.rb
#    `- serializable.rb
#       `- resource.rb