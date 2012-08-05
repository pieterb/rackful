0.1.x
=====
The 0.1.x series is a major revision, not backward compatible with 0.0.x.

0.1.0
-----
*   Complete revision of the {Rackful::HTTPStatus} exception class. From now on,
    there's
    a separate class for each HTTP status code, e.g. {Rackful::HTTP404NotFound}.
*   {Rackful::Path}, a subclass of `String`, is used for HTTP paths. This allows
    serializers, especially for hypermedia, to distinguish paths from "ordinary"
    strings, and render them accordingly.
*   The concept of {Rackful::Serializer Serializers} was introduced. A serializer
    is an object that knows how to serialize an object to a certain media type.
*   The mechanism for content negotiation has changed completely. See
    {Rackful::Resource#serializer} and {Rackful::Resource::ClassMethods#best_content_type}.
*   The mechanism for implementing HTTP method handlers has changed. See
    {Rackful::Resource#do_METHOD} and {Rackful::Resource::ClassMethods#add_parser}.

0.0.x
=====

0.0.2
-----
*   Improved documentation