# encoding: utf-8


require 'rackful'


module Rackful::WebDAV


  RESOURCETYPE_COLLECTION = '<D:collection/>'
  RESOURCETYPE_PRINCIPAL  = '<D:principal/>'


  CONDITION_PRESERVED_LIVE_PROPERTIES = '<D:preserved-live-properties/>'
  # TODO a lot more consts


end


require 'webdav/parser.rb'
require 'webdav/resource.rb'
