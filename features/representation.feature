Feature: Representation
  Resources can have multiple representations.

  Background: 
    #Given test server "App1"

  Scenario: GET a resource
    When I GET "/greeter"
    Then the HTTP response status should be "200 Ok"
    And the HTTP "Content-Type" response header should be "text/plain; charset="utf-8""
    And the response entity should be
      """
      Hello world!
      """

  Scenario: GET a non-existing resource
    When I GET "/non_existing_url"
    Then the HTTP response status should be "404 Not Found"

  