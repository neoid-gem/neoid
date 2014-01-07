module Neoid
  class Instance
    attr_accessor :db
    attr_accessor :logger
    attr_accessor :ref_node
    attr_accessor :env_loaded
    attr_reader :config

    def initialize(connection)
      self.db = connection
    end
    
    def node_models
      @node_models ||= []
    end
    
    def relationship_models
      @relationship_models ||= []
    end

    def config
      @config ||= begin
        c = Neoid::Config.new

        # default
        c.enable_subrefs = true
        c.enable_per_model_indexes = false

        c
      end
    end

    def configure
      yield config
    end

    def initialize_all
      @env_loaded = true
      logger.info "Neoid initialize_all"
      initialize_relationships
      initialize_server
    end

    def initialize_server
      initialize_auto_index
      initialize_subrefs
      initialize_per_model_indexes
    end
    
    def db
      raise "Must set Neoid::Instance.db with a Neography::Rest instance" unless @db
      @db
    end

    def batch(options={}, &block)
      Neoid::Batch.new(self, options, &block).run
    end
    
    def logger
      @logger ||= Logger.new(ENV['NEOID_LOG'] ? ENV['NEOID_LOG_FILE'] || $stdout : '/dev/null')
    end
    
    def ref_node
      @ref_node ||= Neography::Node.load(db.get_root['self'])
    end
    
    def reset_cached_variables
      initialize_subrefs
    end
    
    def clean_db(confirm)
      puts "must call with confirm: Neoid.clean_db(:yes_i_am_sure)" and return unless confirm == :yes_i_am_sure
      Neoid::NeoDatabaseCleaner.clean_db(self)
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

    def execute_script_or_add_to_batch(gremlin_query, script_vars)
      if Neoid::Batch.current_batch
        # returns a SingleResultPromiseProxy!
        Neoid::Batch.current_batch << [:execute_script, gremlin_query, script_vars]
      else
        value = db.execute_script(gremlin_query, script_vars)

        value = yield(value) if block_given?

        Neoid::BatchPromiseProxy.new(value)
      end
    end

    # create a fulltext index if not exists
    def ensure_default_fulltext_search_index
      db.create_node_index(Neoid::DEFAULT_FULLTEXT_SEARCH_INDEX_NAME, 'fulltext', 'lucene') unless (indexes = db.list_node_indexes) && indexes[Neoid::DEFAULT_FULLTEXT_SEARCH_INDEX_NAME]
    end

    def search(types, term, options = {})
      options = options.reverse_merge(limit: 15,match_type: "AND")

      types = [*types]

      query = []

      types.each do |type|
        query_for_type = []

        query_for_type << "ar_type:#{type.name}"

        case term
        when String
          search_in_fields = type.neoid_config.search_options.fulltext_fields.keys
          next if search_in_fields.empty?
          query_for_type << search_in_fields.map{ |field| generate_field_query(field, term, true, options[:match_type]) }.join(" OR ")
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

        idx = g.getRawGraph().index().forNodes('#{Neoid::DEFAULT_FULLTEXT_SEARCH_INDEX_NAME}')
        hits = idx.query('#{sanitize_query_for_gremlin(query)}')

        hits = #{options[:limit] ? "hits.take(#{options[:limit]})" : "hits"}

        #{options[:after_query]}
      GREMLIN

      logger.info "[NEOID] search:\n#{gremlin_query}"

      results = db.execute_script(gremlin_query)

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

      def generate_field_query(field, term, fulltext = false, match_type = "AND")
        term = term.to_s if term
        return "" if term.nil? || term.empty?

        fulltext = fulltext ? "_fulltext" : nil
        valid_match_types = %w( AND OR )
        match_type = valid_match_types.delete(match_type)
        raise "Invalid match_type option. Valid values are #{valid_match_types.join(',')}" unless match_type

        "(" + term.split(/\s+/).reject(&:empty?).map{ |t| "#{field}#{fulltext}:#{sanitize_term(t)}" }.join(" #{match_type} ") + ")"
      end

      def initialize_relationships
        logger.info "Neoid initialize_relationships"
        relationship_models.each do |rel_model|
          Relationship.initialize_relationship(rel_model)
        end
      end

      def initialize_auto_index
        logger.info "Neoid initialize_auto_index"
        db.set_node_auto_index_status(true)
        db.add_node_auto_index_property(Neoid::UNIQUE_ID_KEY)

        db.set_relationship_auto_index_status(true)
        db.add_relationship_auto_index_property(Neoid::UNIQUE_ID_KEY)
      end

      def initialize_subrefs
        return unless config.enable_subrefs
        
        node_models.each do |klass|
          klass.reset_neo_subref_node
        end

        logger.info "Neoid initialize_subrefs"
        batch do
          node_models.each(&:neo_subref_node)
        end.then do |results|
          node_models.zip(results).each do |klass, subref|
            klass.neo_subref_node = subref
          end
        end
      end

      def initialize_per_model_indexes
        return unless config.enable_per_model_indexes

        logger.info "Neoid initialize_subrefs"
        batch do
          node_models.each(&:neo_model_index)
        end
      end
  end
end
