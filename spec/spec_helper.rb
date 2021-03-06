require 'neoid'
require 'active_record'
require 'neography'
require 'rest-client'
require 'codeclimate-test-reporter'
require 'factory_girl'
require 'rspec/its'

CodeClimate::TestReporter.start if ENV['CODECLIMATE_REPO_TOKEN']

require 'simplecov'

require "factories.rb"

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::HTMLFormatter,
]

SimpleCov.start

uri = URI.parse('http://localhost:7474')
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

Neoid.configure do |config|
  config.enable_subrefs = false
end

logger, ActiveRecord::Base.logger = ActiveRecord::Base.logger, Logger.new('/dev/null')
ActiveRecord::Base.configurations = YAML::load(IO.read(File.join(File.dirname(__FILE__), 'support/database.yml')))
ActiveRecord::Base.establish_connection(:sqlite3)

require 'support/schema'
require 'support/models'

ActiveRecord::Base.logger = logger

RSpec.configure do |config|
  config.include FactoryGirl::Syntax::Methods

  config.mock_with :rspec

  config.before(:all) do
  end

  config.before(:each) do
    Neoid.node_models.each(&:destroy_all)
    Neoid.clean_db(:yes_i_am_sure)
    Neoid.reset_cached_variables
  end
end

Neoid.initialize_all
