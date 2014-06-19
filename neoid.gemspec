$LOAD_PATH.push File.expand_path('../lib', __FILE__)
require 'neoid/version'

Gem::Specification.new do |s|
  s.name        = 'neoid'
  s.version     = Neoid::VERSION
  s.authors     = ['Ben Morgan', 'Elad Ossadon']
  s.email       = ['ben@benmorgan.io', 'elad@ossadon.com']
  s.homepage    = 'https://github.com/neoid-gem/neoid'
  s.summary     = 'Neo4j for ActiveRecord'
  s.description = 'Extend Ruby on Rails ActiveRecord with Neo4j nodes. Keep RDBMS and utilize the power of Neo4j queries. Originally by @elado.'
  s.license     = 'MIT'

  s.files = Dir['{app,config,db,lib}/**/*', 'LICENSE', 'Rakefile', 'README.md']
  s.test_files = Dir['spec/**/*']
  s.require_paths = ['lib']

  s.add_development_dependency 'rake'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rest-client'
  s.add_development_dependency 'activerecord'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'codeclimate-test-reporter'
  s.add_development_dependency 'rspec-its'
  s.add_development_dependency 'factory_girl'

  s.add_runtime_dependency 'neography'
end
