When(/^I GET "(\/\S*)"$/) do
  | path |
  get "http://localhost#{path}"
end

Then(/^the HTTP response status should be "(\d\d\d)(?: (.*?))?"$/i) do
  |status_code, status_name|
  status_code = status_code.to_i
  last_response.status.should == status_code
  unless status_name.empty?
    status_name.downcase.should == Rack::Utils::HTTP_STATUS_CODES[status_code].downcase
  end
end

Then(/^the HTTP "(.*?)" response header should be "(.*?)"$/) do
  | name, value |
  last_response[name].should == value
end

Then(/^the response entity should be$/) do |string|
  last_response.body.should == string
end
