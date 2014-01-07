module Neoid
  module Node
    def self.from_hash(hash)
      node = Neography::Node.new(hash)
      node.neo_server = self.neo4j_connection.db
      node
    end

    module ClassMethods
      attr_accessor :neo_subref_node

      def neo_subref_rel_type
        @_neo_subref_rel_type ||= "#{self.name.tableize}_subref"
      end

      def neo_subref_node_rel_type
        @_neo_subref_node_rel_type ||= self.name.tableize
      end

      def delete_command
        :delete_node
      end

      def neo4j_connection
        @neo4j_connection ||= begin
          instance = Neoid.connection(@neo4j_connection_name)
          instance.node_models << self
          instance
        end
      end

      def neo_model_index
        return nil unless self.neo4j_connection.config.enable_per_model_indexes

        self.neo4j_connection.logger.info "Node#neo_model_index #{neo_subref_rel_type}"

        gremlin_query = <<-GREMLIN
          g.createManualIndex(neo_model_index_name, Vertex.class);
        GREMLIN

        # self.neo4j_connection.logger.info "subref query:\n#{gremlin_query}"

        script_vars = { neo_model_index_name: neo_model_index_name }

        self.neo4j_connection.execute_script_or_add_to_batch gremlin_query, script_vars
      end

      def neo_subref_node
        return nil unless self.neo4j_connection.config.enable_subrefs

        @neo_subref_node ||= begin
          self.neo4j_connection.logger.info "Node#neo_subref_node #{neo_subref_rel_type}"

          gremlin_query = <<-GREMLIN
            q = g.v(0).out(neo_subref_rel_type);

            subref = q.hasNext() ? q.next() : null;

            if (!subref) {
              subref = g.addVertex([name: neo_subref_rel_type, type: name]);
              g.addEdge(g.v(0), subref, neo_subref_rel_type);
            }

            subref
          GREMLIN

          # self.neo4j_connection.logger.info "subref query:\n#{gremlin_query}"

          script_vars = {
            neo_subref_rel_type: neo_subref_rel_type,
            name: self.name
          }

          self.neo4j_connection.execute_script_or_add_to_batch gremlin_query, script_vars do |value|
            Neoid::Node.from_hash(value)
          end
        end
      end

      def reset_neo_subref_node
        @neo_subref_node = nil
      end

      def neo_search(term, options = {})
        self.neo4j_connection.search(self, term, options)
      end
    end
    
    module InstanceMethods
      def neo_find_by_id
        # self.neo4j_connection.logger.info "Node#neo_find_by_id #{self.class.neo_index_name} #{self.id}"
        node = self.class.neo4j_connection.db.get_node_auto_index(Neoid::UNIQUE_ID_KEY, self.neo_unique_id)
        node.present? ? Neoid::Node.from_hash(node[0]) : nil
      end
      
      def _neo_save
        return unless self.class.neo4j_connection.enabled?

        data = self.to_neo.merge(ar_type: self.class.name, ar_id: self.id, Neoid::UNIQUE_ID_KEY => self.neo_unique_id)
        data.reject! { |k, v| v.nil? }

        gremlin_query = <<-GREMLIN
          idx = g.idx('node_auto_index');
          q = null;
          if (idx) q = idx.get(unique_id_key, unique_id);

          node = null;
          if (q && q.hasNext()) {
            node = q.next();
            node_data.each {
              if (node.getProperty(it.key) != it.value) {
                node.setProperty(it.key, it.value);
              }
            }
          } else {
            node = g.addVertex(node_data);
            if (enable_subrefs) g.addEdge(g.v(subref_id), node, neo_subref_node_rel_type);

            if (enable_model_index) g.idx(neo_model_index_name).put('ar_id', node.ar_id, node);
          }

          node
        GREMLIN

         script_vars = {
          unique_id_key: Neoid::UNIQUE_ID_KEY,
          node_data: data,
          unique_id: self.neo_unique_id,
          enable_subrefs: self.class.neo4j_connection.config.enable_subrefs,
          enable_model_index: self.class.neo4j_connection.config.enable_per_model_indexes && self.class.neoid_config.enable_model_index
        }

        if self.class.neo4j_connection.config.enable_subrefs
          script_vars.update(
            subref_id: self.class.neo_subref_node.neo_id,
            neo_subref_node_rel_type: self.class.neo_subref_node_rel_type
          )
        end

        if self.class.neo4j_connection.config.enable_per_model_indexes && self.class.neoid_config.enable_model_index
          script_vars.update(
            neo_model_index_name: self.class.neo_model_index_name
          )
        end

        self.neo4j_connection.logger.info "Node#neo_save #{self.class.name} #{self.id}"

        node = self.class.neo4j_connection.execute_script_or_add_to_batch(gremlin_query, script_vars) do |value|
          @_neo_representation = Neoid::Node.from_hash(value)
        end.then do |result|
          neo_search_index
        end

        node
      end

      def neo_search_index
        return if self.class.neoid_config.search_options.blank? || (
          self.class.neoid_config.search_options.index_fields.blank? &&
          self.class.neoid_config.search_options.fulltext_fields.blank?
        )

        self.class.neo4j_connection.ensure_default_fulltext_search_index

        self.class.neo4j_connection.db.add_node_to_index(Neoid::DEFAULT_FULLTEXT_SEARCH_INDEX_NAME, 'ar_type', self.class.name, neo_node.neo_id)

        self.class.neoid_config.search_options.fulltext_fields.each do |field, options|
          self.class.neo4j_connection.db.add_node_to_index(Neoid::DEFAULT_FULLTEXT_SEARCH_INDEX_NAME, "#{field}_fulltext", neo_helper_get_field_value(field, options), neo_node.neo_id)
        end

        self.class.neoid_config.search_options.index_fields.each do |field, options|
          self.class.neo4j_connection.db.add_node_to_index(Neoid::DEFAULT_FULLTEXT_SEARCH_INDEX_NAME, field, neo_helper_get_field_value(field, options), neo_node.neo_id)
        end

        neo_node
      end

      def neo_helper_get_field_value(field, options = {})
        if options[:block]
          options[:block].call
        else
          self.send(field) rescue (raise "No field #{field} for #{self.class.name}")
        end
      end
      
      def neo_load(hash)
        Neoid::Node.from_hash(hash)
      end
      
      def neo_node
        _neo_representation
      end

      def neo_after_relationship_remove(relationship)
        relationship.neo_destroy
      end

      def neo_before_relationship_through_remove(record)
        rel_model, foreign_key_of_owner, foreign_key_of_record = Neoid::Relationship.meta_data[self.class.name.to_s][record.class.name.to_s]
        rel_model = rel_model.to_s.constantize
        @__neo_temp_rels ||= {}
        @__neo_temp_rels[record] = rel_model.where(foreign_key_of_owner => self.id, foreign_key_of_record => record.id).first
      end

      def neo_after_relationship_through_remove(record)
        @__neo_temp_rels.each { |r, relationship| relationship.neo_destroy }
        @__neo_temp_rels.delete(record)
      end
    end
      
    def self.included(receiver)
      receiver.send :include, Neoid::ModelAdditions
      receiver.extend         ClassMethods
      receiver.send :include, InstanceMethods
    end
  end
end
