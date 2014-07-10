Feature: Representation
  Resources can have multiple representations.

  Background: 
    Given test server "APP1"

  Scenario: GET a resource without a Serializer
    When I GET "/greeter"
    Then the HTTP response status should be "200 Ok"
    And the HTTP "Content-Type" response header should be "text/plain; charset="UTF-8""
    And the response entity should be
      """
      Hello world!
      """

  Scenario: GET a resource with a Serializer
    When I GET "/representables/hello"
    Then the HTTP response status should be "200 Ok"
    And the HTTP "Content-Type" response header should be "application/hal+json"
    And the response entity should be valid HALJSON

  Scenario: GET a non-existing resource
    When I GET "/non_existing_url"
    Then the HTTP response status should be "404 Not Found"
