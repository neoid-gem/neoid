$LOAD_PATH.push File.expand_path('../lib', __FILE__)
require 'neoid/version'

Gem::Specification.new do |s|
  s.name        = 'neoid'
  s.version     = Neoid::VERSION
  s.authors     = ['Ben Morgan']
  s.email       = ['ben@benmorgan.io']
  s.homepage    = ''
  s.summary     = %q(Neo4j for ActiveRecord)
  s.description = %q(Extend Ruby on Rails ActiveRecord with Neo4j nodes. Keep RDBMS and utilize the power of Neo4j queries. Originally by @elado.)

  s.rubyforge_project = 'neoid'

  s.files         = `git ls-files`.split('\n')
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split('\n')
  s.executables   = `git ls-files -- bin/*`.split('\n').map{ |f| File.basename(f) }
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
