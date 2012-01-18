module Neoid
  class ModelConfig
    @properties = []
  
    attr_accessor :properties
  
    def property(name)
      @properties << name
    end
  end
end
