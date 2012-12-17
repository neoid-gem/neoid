module Neoid
  module Node
    module ClassMethods
      def neo_subref_rel_type
        @_neo_subref_rel_type ||= "#{self.name.tableize}_subref"
      end
      def neo_subref_node_rel_type
        @_neo_subref_node_rel_type ||= self.name.tableize
      end
      
      def neo_subref_node
        @_neo_subref_node ||= begin
          Neoid::logger.info "Node#neo_subref_node #{neo_subref_rel_type}"

          gremlin_query = <<-GREMLIN
            q = g.v(0).out(neo_subref_rel_type);

            subref = q.hasNext() ? q.next() : null;

            if (!subref) {
              subref = g.addVertex([name: neo_subref_rel_type, type: name]);
              g.addEdge(g.v(0), subref, neo_subref_rel_type);
            }

            g.createManualIndex(neo_index_name, Vertex.class);

            subref
          GREMLIN

          Neoid.logger.info "subref query:\n#{gremlin_query}"

          node = Neography::Node.load(Neoid.db.execute_script(gremlin_query, neo_subref_rel_type: neo_subref_rel_type, name: self.name, neo_index_name: self.neo_index_name))

          node
        end
      end

      def neo_search(term, options = {})
        Neoid.search(self, term, options)
      end
    end
    
    module InstanceMethods
      def neo_find_by_id
        Neoid::logger.info "Node#neo_find_by_id #{self.class.neo_index_name} #{self.id}"
        Neoid.db.get_node_index(self.class.neo_index_name, :ar_id, self.id)
      rescue Neography::NotFoundException
        nil
      end
      
      def neo_create
        return unless Neoid.enabled?
        
        data = self.to_neo.merge(ar_type: self.class.name, ar_id: self.id)
        data.reject! { |k, v| v.nil? }
        
        node = Neography::Node.create(data)
        
        retires = 2
        begin
          Neography::Relationship.create(
            self.class.neo_subref_node_rel_type,
            self.class.neo_subref_node,
            node
          )
        rescue
          # something must've happened to the cached subref node, reset and retry
          @_neo_subref_node = nil
          retires -= 1
          retry if retires > 0
        end

        Neoid.db.add_node_to_index(self.class.neo_index_name, :ar_id, self.id, node)

        Neoid::logger.info "Node#neo_create #{self.class.name} #{self.id}, index = #{self.class.neo_index_name}"
        
        neo_search_index

        node
      end
      
      def neo_update
        Neoid.db.set_node_properties(neo_node, self.to_neo)
        neo_search_index
      end
      
      def neo_search_index
        return if self.class.neoid_config.search_options.blank? || (
          self.class.neoid_config.search_options.index_fields.blank? &&
          self.class.neoid_config.search_options.fulltext_fields.blank?
        )

        Neoid.ensure_default_fulltext_search_index

        Neoid.db.add_node_to_index(DEFAULT_FULLTEXT_SEARCH_INDEX_NAME, 'ar_type', self.class.name, neo_node.neo_id)

        self.class.neoid_config.search_options.fulltext_fields.each do |field, options|
          Neoid.db.add_node_to_index(DEFAULT_FULLTEXT_SEARCH_INDEX_NAME, "#{field}_fulltext", neo_helper_get_field_value(field, options), neo_node.neo_id)
        end

        self.class.neoid_config.search_options.index_fields.each do |field, options|
          Neoid.db.add_node_to_index(DEFAULT_FULLTEXT_SEARCH_INDEX_NAME, field, neo_helper_get_field_value(field, options), neo_node.neo_id)
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
      
      def neo_load(node)
        Neography::Node.load(node)
      end
      
      def neo_node
        _neo_representation
      end
    
      def neo_destroy
        return unless neo_node
        Neoid.db.remove_node_from_index(DEFAULT_FULLTEXT_SEARCH_INDEX_NAME, neo_node)

        Neoid.db.remove_node_from_index(self.class.neo_index_name, neo_node)
        neo_node.del
        _reset_neo_representation
      end

      def neo_after_relationship_remove(relationship)
        relationship.neo_destroy
      end

      def neo_before_relationship_through_remove(record)
        rel_model, foreign_key_of_owner, foreign_key_of_record = Neoid.config[:relationship_meta_data][self.class.name.to_s][record.class.name.to_s]
        rel_model = rel_model.to_s.constantize
        @__neo_temp_rels ||= {}
        @__neo_temp_rels[record] = rel_model.where(foreign_key_of_owner => self.id, foreign_key_of_record => record.id).first
      end

      def neo_after_relationship_through_remove(record)
        @__neo_temp_rels.each { |record, relationship| relationship.neo_destroy }
        @__neo_temp_rels.delete(record)
      end
    end
      
    def self.included(receiver)
      receiver.send :include, Neoid::ModelAdditions
      receiver.extend         ClassMethods
      receiver.send :include, InstanceMethods
      Neoid.node_models << receiver
      
      receiver.after_create :neo_create
      receiver.after_update :neo_update
      receiver.after_destroy :neo_destroy
    end
  end
end
