module Neoid
  module Relationship
    module InstanceMethods
      def neo_find_by_id
        Neoid.db.get_relationship_index(self.class.neo_index_name, :ar_id, self.id)
      end
      
      def neo_create
        return unless Neoid.enabled?
        
        options = self.class.neoid_config.relationship_options
        
        start_node = self.send(options[:start_node])
        end_node = self.send(options[:end_node])
        
        return unless start_node && end_node
        
        relationship = Neography::Relationship.create(
          options[:type].is_a?(Proc) ? options[:type].call(self) : options[:type],
          start_node.neo_node,
          end_node.neo_node
        )
        
        Neoid.db.add_relationship_to_index(self.class.neo_index_name, :ar_id, self.id, relationship)

        Neoid::logger.info "Relationship#neo_create #{self.class.name} #{self.id}, index = #{self.class.neo_index_name}"
        
        relationship
      end
      
      def neo_load(relationship)
        Neography::Relationship.load(relationship)
      end
      
      def neo_destroy
        return unless neo_relationship
        Neoid.db.remove_relationship_from_index(self.class.neo_index_name, neo_relationship)
        neo_relationship.del
        _reset_neo_representation
        true
      end
      
      def neo_relationship
        _neo_representation
      end
    end

    def self.included(receiver)
      receiver.send :include, Neoid::ModelAdditions
      receiver.send :include, InstanceMethods
      
      receiver.after_create :neo_create
      receiver.after_destroy :neo_destroy
    end
  end
end