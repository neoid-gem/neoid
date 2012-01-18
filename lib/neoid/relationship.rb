module Neoid
  module Relationship
    module InstanceMethods
      def neo_find_by_id
        Neoid.db.get_relationship_index(neo_index_name, :ar_id, self.id)
      end
      
      def neo_create
        options = self.class.neoidable_options
        
        start_node = self.send(options[:start_node])
        end_node = self.send(options[:end_node])
        
        return unless start_node && end_node
        
        relationship = Neography::Relationship.create(
          options[:type],
          start_node.neo_node,
          end_node.neo_node
        )
        
        Neoid.db.add_relationship_to_index(neo_index_name, :ar_id, self.id, relationship)
        
        relationship
      end
      
      def neo_load(relationship)
        Neography::Relationship.load(relationship)
      end
      
      def neo_destroy
        return unless neo_relationship
        Neoid.db.remove_relationship_from_index(neo_index_name, neo_relationship)
        puts neo_relationship.del
      end
      
      def neo_relationship
        _neo_representation
      end
    end

    def self.included(receiver)
      Neoid.db.create_relationship_index(receiver.name.tableize)

      receiver.extend         Neoid::ModelAdditions::ClassMethods
      receiver.send :include, Neoid::ModelAdditions::InstanceMethods
      receiver.send :include, InstanceMethods
      
      receiver.after_create :neo_create
      receiver.after_destroy :neo_destroy
    end
  end
end