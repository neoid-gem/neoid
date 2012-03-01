module Neoid
  class ModelConfig
    attr_reader :properties
    attr_reader :search_options
    attr_reader :relationship_options
    
    def initialize(klass)
      @klass = klass
    end
    
    def stored_fields
      @stored_fields ||= []
    end
    
    def field(name)
      self.stored_fields << name
    end
    
    def relationship(options)
      @relationship_options = options
    end
    
    def search(&block)
      raise "search needs a block" unless block_given?
      @search_options = SearchConfig.new
      block.(@search_options)
    end
    
    def inspect
      "#<Neoid::ModelConfig @properties=#{properties.inspect} @search_options=#{@search_options.inspect}>"
    end
  end
  
  class SearchConfig
    def index_fields
      @index_fields ||= {}
    end
    
    def index(field, options = {})
      index_fields[field] = options
    end
    
    def inspect
      "#<Neoid::SearchConfig @index_fields=#{index_fields.inspect}>"
    end
  end
end
