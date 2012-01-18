require 'neoid'
require 'supermodel'
require 'neography'
require 'rest-client'

uri = URI.parse(ENV["NEO4J_URL"] || "http://localhost:7574")
$neo = Neography::Rest.new(uri.to_s)

Neography::Config.tap do |c|
  c.server = uri.host
  c.port = uri.port

  if uri.user && uri.password
    c.authentication = 'basic'
    c.username = uri.user
    c.password = uri.password
  end
end

Neoid.db = $neo

RSpec.configure do |config|
  config.mock_with :rspec

  config.before(:all) do
    RestClient.delete "#{uri}/cleandb/secret-key"
  end
end
