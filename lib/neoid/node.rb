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
          
          subref_node_query = Neoid.ref_node.outgoing(neo_subref_rel_type)

          if subref_node_query.to_a.blank?
            Neoid::logger.info "Node#neo_subref_node not existing, creating #{neo_subref_rel_type}"
            
            node = Neography::Node.create(type: self.name, name: neo_subref_rel_type)
            Neography::Relationship.create(
              neo_subref_rel_type,
              Neoid.ref_node,
              node
            )
          else
            Neoid::logger.info "Node#neo_subref_node existing, fetching #{neo_subref_rel_type}"
            node = subref_node_query.first
            Neoid::logger.info "Node#neo_subref_node existing, fetched #{neo_subref_rel_type}"
          end
        
          node
        end
      end

      def search(term, options = {})
        Neoid.search(self, term, options)
      end
    end
    
    module InstanceMethods
      def neo_find_by_id
        Neoid::logger.info "Node#neo_find_by_id #{self.class.neo_index_name} #{self.id}"
        Neoid.db.get_node_index(self.class.neo_index_name, :ar_id, self.id)
      end
      
      def neo_create
        return unless Neoid.enabled?
        
        data = self.to_neo.merge(ar_type: self.class.name, ar_id: self.id)
        
        node = Neography::Node.create(data)
        
        Neography::Relationship.create(
          self.class.neo_subref_node_rel_type,
          self.class.neo_subref_node,
          node
        )
        
        Neoid.db.add_node_to_index(self.class.neo_index_name, :ar_id, self.id, node)

        Neoid::logger.info "Node#neo_create #{self.class.name} #{self.id}, index = #{self.class.neo_index_name}"
        
        neo_search_index

        node
      end
      
      def neo_update
        Neoid.db.set_node_properties(neo_node, self.to_neo)
        neo_search_index
        
        neo_node
      end
      
      def neo_search_index
        return if self.class.neoid_config.search_options.blank? || (
          self.class.neoid_config.search_options.index_fields.blank? &&
          self.class.neoid_config.search_options.fulltext_fields.blank?
        )

        Neoid.ensure_default_fulltext_search_index

        Neoid.db.add_node_to_index(DEFAULT_FULLTEXT_SEARCH_INDEX_NAME, 'ar_type', self.class.name, neo_node.neo_id)

        self.class.neoid_config.search_options.fulltext_fields.each { |field, options|
          Neoid.db.add_node_to_index(DEFAULT_FULLTEXT_SEARCH_INDEX_NAME, "#{field}_fulltext", neo_helper_get_field_value(field, options), neo_node.neo_id)
        }

        self.class.neoid_config.search_options.index_fields.each { |field, options|
          Neoid.db.add_node_to_index(DEFAULT_FULLTEXT_SEARCH_INDEX_NAME, field, neo_helper_get_field_value(field, options), neo_node.neo_id)
        }

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
      
      receiver.neo_subref_node # ensure
      
      receiver.after_create :neo_create
      receiver.after_update :neo_update
      receiver.after_destroy :neo_destroy
    end
  end
end