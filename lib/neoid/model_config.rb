module Neoid
  class ModelConfig
    attr_reader :properties
    attr_reader :search_options
    attr_reader :relationship_options
    attr_accessor :enable_model_index
    attr_accessor :auto_index

    def initialize(klass)
      @klass = klass
    end

    def stored_fields
      @stored_fields ||= {}
    end

    def field(name, &block)
      self.stored_fields[name] = block
    end

    def stored_json_fields
      @stored_json_fields ||= []
    end

    def json_field(name)
      self.stored_json_fields << name
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

    def fulltext_fields
      @fulltext_fields ||= {}
    end

    def index(field, options = {}, &block)
      index_fields[field] = options.merge(block: block)
    end

    def fulltext(field, options = {}, &block)
      fulltext_fields[field] = options.merge(block: block)
    end

    def inspect
      "#<Neoid::SearchConfig @index_fields=#{index_fields.inspect} @fulltext_fields=#{fulltext_fields.inspect}>"
    end
  end
end
