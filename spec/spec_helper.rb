require 'neoid'
require 'active_record'
require 'neography'
require 'rest-client'

uri = URI.parse(ENV["NEO4J_URL"] ? ENV["NEO4J_URL"] : ENV['TRAVIS'] ? "http://localhost:7474" : "http://localhost:7574")
$neo = Neography::Rest.new(uri.to_s)

Neography.configure do |c|
  c.server = uri.host
  c.port = uri.port

  if uri.user && uri.password
    c.authentication = 'basic'
    c.username = uri.user
    c.password = uri.password
  end
end

Neoid.db = $neo

ActiveRecord::Base.configurations = YAML::load(IO.read(File.join(File.dirname(__FILE__), 'support/database.yml')))
ActiveRecord::Base.establish_connection('sqlite3')

RSpec.configure do |config|
  config.mock_with :rspec

  config.before(:all) do
  end
  
  config.before(:each) do
    Neoid.reset_cached_variables
  end

  config.before(:each) do
    Neoid.clean_db(:yes_i_am_sure)
    Neoid.models.each(&:destroy_all)
  end
end

require 'support/schema'
require 'support/models'

Neoid.initialize_all