require 'neoid'
require 'active_record'
require 'neography'
require 'rest-client'
require 'database_cleaner'

uri = URI.parse(ENV["NEO4J_URL"] ? ENV["NEO4J_URL"] : ENV['TRAVIS'] ? "http://localhost:7474" : "http://localhost:7574")
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

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

  config.before(:all) do
    dir = File.join(File.dirname(__FILE__), 'support/db')
    
    old_db = File.join(dir, 'test.sqlite3')
    blank_db = File.join(dir, '.blank.sqlite3')
    
    if !File.exists?(blank_db)
      FileUtils.cp(File.join(dir, 'test.sqlite3'), File.join(dir, '.blank.sqlite3'))
    elsif File.exists?(old_db)
      FileUtils.rm(old_db)
      FileUtils.cp(File.join(dir, '.blank.sqlite3'), File.join(dir, 'test.sqlite3'))
    end
  end

  config.before(:all) do
  end
  
  config.before(:each) do
    Neoid.clean_db(:yes_i_am_sure) unless ENV['TRAVIS']
    Neoid.reset_cached_variables
  end
end

require 'support/connection'
require 'support/models'