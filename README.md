Rackful
=======

a library for creating Rackfulful web services

Rationale
---------

Confronted with the task of implementing a Rackfulful web service in Ruby, I
checked out a number of existing libraries and frameworks, including
Ruby-on-Rails, and then decided to brew my own, the reason being that I couldn't
find a library or framework with all of the following properties:

*   **Small** Some of these frameworks are really big. I need to get a job done in
    time. If understanding the framework takes more time than writing my own, I
    must at least feel confident that the framework I'm learning is more powerful
    that what I can come up with by myself. Ruby-on-Rails is probably the biggest
    framework out there, and it still lacks many features that are essential to
    Rackfulful web service programming.

    This library is small. You could read _all_ the source code in less than an
    hour, and understand every detail.

*   **No extensive tooling or code generation** Code generation has been the
    subject of more than one flame-war over the years. Not much I can add to the
    debate. <em>But still,</em> with a language as dynamic as Ruby, you just
    shouldn't need code generation. Ever.

*   **Full support for conditional requests** using `If-*:` request headers. Most
    libraries' support is limited to `If-None-Match:` and `If-Modified-Since:`
    headers, and only for `GET` and `HEAD` requests. For Rackfulful web services,
    the `If-Match:` and `If-Unmodified-Since:` headers are at least as important,
    particularly for unsafe methods like `PUT`, `POST`, `PATCH`, and `DELETE`.

    This library fully supports the `ETag:` and `Last-Modified:` headers, and all
    `If-*:` headers.

*   **Resource centered** Some libraries claim Rackfulfulness, but at the same
    time have a servet-like interface, which requires you to implement method
    handles such as `doPOST(url)`. In these method handlers you have to find out
    what resource is posted to, depending on the URL.

    This library requires that you implement a Resource Factory which maps URIs
    to resource Objects. These objects will then receive HTTP requests.

Hello World!
------------

Here's a working example of a simple Rackful server:

{include:file:example/config.ru}

This file is included in the distribution as `example/config.ru`.
If you go to the `example` directory and run `rackup`, you should see
something like this:

    $> rackup
    [2012-07-10 11:45:32] INFO  WEBrick 1.3.1
    [2012-07-10 11:45:32] INFO  ruby 1.9.2 (2011-12-27) [java]
    [2012-07-10 11:45:32] INFO  WEBrick::HTTPServer#start: pid=5994 port=9292

Go with your browser to {http://localhost:9292/} and be greeted.

In this example, we implement `GET` and `PUT` requests for the resource at '/'. but
we get a few things for free:

### Free `OPTIONS` response:

Request:

    OPTIONS / HTTP/1.1
    Host: localhost:9292

Response:

    HTTP/1.1 204 No Content 
    Allow: PUT, GET, HEAD, OPTIONS
    Date: Tue, 10 Jul 2012 10:22:52 GMT

As you can see, the server accurately reports all available methods for the
resource. Notice the availability of the `HEAD` method; if you implement the
`GET` method, you'll get `HEAD` for free. It's still a good idea to explicitly
implement your own `HEAD` request handler, especially for expensive resources,
when responding to a `HEAD` request should be much more efficient than generating
a full `GET` response, and strip off the response body.

### Free conditional request handling:

Let's first get the current state of the resource, with this request:

    GET / HTTP/1.1
    Host: localhost:9292

Response:

    HTTP/1.1 200 OK 
    Content-Type: text/plain
    Content-Length: 12
    ETag: "86fb269d190d2c85f6e0468ceca42a20"
    Date: Tue, 10 Jul 2012 10:34:36 GMT
    
    Hello world!

Now, we'd like to change the state of the resource, but only if it's still in
the state we last saw, to avoid the "lost update problem". To do that, we
produce an `If-Match:` header, with the entity tag of our last version:

    PUT / HTTP/1.1
    Host: localhost:9292
    Content-Type: text/plain
    Content-Length: 31
    If-Match: "86fb269d190d2c85f6e0468ceca42a20"
    
    All your base are belong to us.

Response:

    HTTP/1.1 204 No Content
    ETag: "920c1e9267f923c62b55a471c1d8a528"
    Date: Tue, 10 Jul 2012 10:58:57 GMT

The response contains an `ETag:` header, with the _new_ entity tag of this
resource. When we replay this request, we get the following response:

    HTTP/1.1 412 Precondition Failed
    Content-Type: text/html; charset="UTF-8"
    Date: Tue, 10 Jul 2012 11:06:54 GMT
    
    [...]
    <h1>HTTP/1.1 412 Precondition Failed</h1>
    <p>If-Match: "86fb269d190d2c85f6e0468ceca42a20"</p>
    [...]

The server returns with status <tt>412 Precondition Failed</tt>. In the HTML
response body, the server kindly points out exactly which precondition.

Further reading
---------------
*   {Rackful::Server#initialize} for more information about your Resource Factory.
*   {Rackful::Resource#etag} and {Rackful::Resource#last_modified} for more information on
    conditional requests.
*   {Rackful::Resource#do_METHOD} for more information about writing your own request
    handlers.
*   {Rackful::RelativeLocation} for more information about this piece of Rack middleware
    which allows you to return relative and absolute paths in the `Location:`
    response header, and why you'd want that.

Licensing
---------
Copyright ©2011-2012 Pieter van Beek <pieterb@sara.nl>

Licensed under the Apache License 2.0. You should have received a copy of this
license as part of this distribution.

