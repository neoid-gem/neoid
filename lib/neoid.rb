require "neoid/version"
require "neoid/model_config"
require "neoid/model_additions"
require "neoid/node"
require "neoid/relationship"
require "neoid/railtie" if defined? Rails

module Neoid
  class << self
    attr_accessor :db
    attr_accessor :ref_node
    
    def db
      raise "Neoid.db wasn't supplied" unless @db
      @db
    end
    
    def ref_node
      @ref_node ||= Neography::Node.load(Neoid.db.get_root['self'])
    end
  end
end
