# encoding: utf-8


module Rackful


=begin markdown
An object responding to thread safe and reentrant method `#resource`.

A {Server} has no knowledge, and makes no presumptions, about your URI namespace.
It requires a {ResourceFactory resource factory} which produces {Resource resources} given
a certain URI.

The Resource Factory you provide need only implement one method, with signature
`Resource #[]( URI uri )`.
This method will be called with an unnormalized {URI}, and must return a
{Resource}, or `nil` if there’s no resource at the given URI.

For example, if a Rackful client
tries to access a resource with URI `http://example.com/some/resource`,
then your Resource Factory can expect to be called like this:

    uri = URI.parse('http://example.com/some/resource')
    resource = resource_factory[ uri ]

If there’s no resource at the given URI, but you’d still like to respond to
`POST` or `PUT` requests to this URI, you must return an
{Resource#empty? empty resource}.
=end
module ResourceFactory


=begin markdown
@param url [String] The url of the requested resource
@return [Resource, nil]
=end
def [] url
  raise NotImplementedError
end


end # module ResourceFactory


end # module Rackful
