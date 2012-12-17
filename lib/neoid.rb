require 'neoid/version'
require 'neoid/model_config'
require 'neoid/model_additions'
require 'neoid/search_session'
require 'neoid/node'
require 'neoid/relationship'
require 'neoid/database_cleaner'
require 'neoid/railtie' if defined?(Rails)

module Neoid
  DEFAULT_FULLTEXT_SEARCH_INDEX_NAME = 'neoid_default_search_index'

  class << self
    attr_accessor :db
    attr_accessor :logger
    attr_accessor :ref_node
    attr_accessor :env_loaded
    
    def models
      @models ||= []
    end
    
    def node_models
      @node_models ||= []
    end
    
    def relationship_models
      @relationship_models ||= []
    end

    def config
      @config ||= {}
    end

    def initialize_all
      @env_loaded = true
      relationship_models.each do |rel_model|
        Relationship.initialize_relationship(rel_model)
      end
    end
    
    def db
      raise "Must set Neoid.db with a Neography::Rest instance" unless @db
      @db
    end
    
    def logger
      @logger ||= Logger.new(ENV['NEOID_LOG'] ? ENV['NEOID_LOG_FILE'] || $stdout : '/dev/null')
    end
    
    def ref_node
      @ref_node ||= Neography::Node.load(Neoid.db.get_root['self'])
    end
    
    def reset_cached_variables
      Neoid.models.each do |klass|
        klass.instance_variable_set(:@_neo_subref_node, nil)
      end
      $neo_ref_node = nil
    end
    
    def clean_db(confirm)
      puts "must call with confirm: Neoid.clean_db(:yes_i_am_sure)" and return unless confirm == :yes_i_am_sure
      Neoid::NeoDatabaseCleaner.clean_db
    end
    

    def enabled=(flag)
      Thread.current[:neoid_enabled] = flag
    end

    def enabled
      flag = Thread.current[:neoid_enabled]
      # flag should be set by the middleware. in case it wasn't (non-rails app or console), default it to true
      flag.nil? ? true : flag
    end
    alias enabled? enabled

    def use(flag=true)
      old, self.enabled = enabled?, flag
      yield if block_given?
    ensure
      self.enabled = old
    end

    # create a fulltext index if not exists
    def ensure_default_fulltext_search_index
      Neoid.db.create_node_index(DEFAULT_FULLTEXT_SEARCH_INDEX_NAME, 'fulltext', 'lucene') unless (indexes = Neoid.db.list_node_indexes) && indexes[DEFAULT_FULLTEXT_SEARCH_INDEX_NAME]
    end

    def search(types, term, options = {})
      options = options.reverse_merge(limit: 15)

      types = [*types]

      query = []

      types.each do |type|
        query_for_type = []

        query_for_type << "ar_type:#{type.name}"

        case term
        when String
          search_in_fields = type.neoid_config.search_options.fulltext_fields.keys
          next if search_in_fields.empty?
          query_for_type << search_in_fields.map{ |field| generate_field_query(field, term, true) }.join(" OR ")
        when Hash
          term.each do |field, value|
            query_for_type << generate_field_query(field, value, false)
          end
        end

        query << "(#{query_for_type.join(") AND (")})"
      end

      query = "(#{query.join(") OR (")})"

      logger.info "Neoid query #{query}"

      gremlin_query = <<-GREMLIN
        #{options[:before_query]}

        idx = g.getRawGraph().index().forNodes('#{DEFAULT_FULLTEXT_SEARCH_INDEX_NAME}')
        hits = idx.query('#{sanitize_query_for_gremlin(query)}')

        hits = #{options[:limit] ? "hits.take(#{options[:limit]})" : "hits"}

        #{options[:after_query]}
      GREMLIN

      logger.info "[NEOID] search:\n#{gremlin_query}"

      results = Neoid.db.execute_script(gremlin_query)

      SearchSession.new(results, *types)
    end

    private
      def sanitize_term(term)
        # TODO - case sensitive?
        term.downcase
      end

      def sanitize_query_for_gremlin(query)
        # TODO - case sensitive?
        query.gsub("'", "\\\\'")
      end

      def generate_field_query(field, term, fulltext = false)
        term = term.to_s if term
        return "" if term.nil? || term.empty?

        fulltext = fulltext ? "_fulltext" : nil

        "(" + term.split(/\s+/).reject(&:empty?).map{ |t| "#{field}#{fulltext}:#{sanitize_term(t)}" }.join(" AND ") + ")"
      end
  end
end
