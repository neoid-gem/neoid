require "neoid/version"
require "neoid/model_config"
require "neoid/model_additions"
require "neoid/node"
require "neoid/relationship"

module Neoid
  class << self
    attr_accessor :db
    attr_accessor :logger
    attr_accessor :ref_node
    
    def models
      @models ||= []
    end
    
    def db
      raise "Must set Neoid.db with a Neography::Rest instance" unless @db
      @db
    end
    
    def logger
      @logger ||= Logger.new(ENV['NEOID_LOG'] ? $stdout : '/dev/null')
    end
    
    def ref_node
      @ref_node ||= Neography::Node.load(Neoid.db.get_root['self'])
    end
    
    def reset_cached_variables
      Neoid.models.each { |klass|
        klass.instance_variable_set(:@_neo_subref_node, nil)
      }
      $neo_ref_node = nil
    end
    
    def clean_db(confirm)
      puts "must call with confirm: Neoid.clean_db(:yes_i_am_sure)" and return unless confirm == :yes_i_am_sure
      RestClient.delete "#{Neoid.db.protocol}#{Neoid.db.server}:#{Neoid.db.port}/cleandb/secret-key"
    end
    
    def enabled
      return true unless Thread.current[:neoid_use_set]
      Thread.current[:neoid_use]
    end
    
    def enabled=(flag)
      Thread.current[:neoid_use] = flag
      Thread.current[:neoid_use_set] = true
    end
    
    alias enabled? enabled
    
    def use(flag = true)
      old, self.enabled = enabled?, flag
      yield if block_given?
    ensure
      self.enabled = old
    end
  end
end
