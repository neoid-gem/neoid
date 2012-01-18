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
          subref_node_query = Neoid.ref_node.outgoing(neo_subref_rel_type)

          if subref_node_query.to_a.blank?
            node = Neography::Node.create(type: self.name, name: neo_subref_rel_type)
            Neography::Relationship.create(
              neo_subref_rel_type,
              Neoid.ref_node,
              node
            )
          else
            node = subref_node_query.first
          end
        
          node
        end
      end
    end
    
    module InstanceMethods
      def neo_find_by_id
        Neoid.db.get_node_index(neo_index_name, :ar_id, self.id)
      end
      
      def neo_create
        data = self.to_neo.merge(ar_type: self.class.name, ar_id: self.id)
        data.reject! { |k, v| v.nil? }
        
        node = Neography::Node.create(data)
        
        begin
          Neography::Relationship.create(
            self.class.neo_subref_node_rel_type,
            self.class.neo_subref_node,
            node
          )
        rescue Exception => e
          puts [$!.message] + $!.backtrace
          raise e
        end
        
        Neoid.db.add_node_to_index(neo_index_name, :ar_id, self.id, node)
        node
      end
      
      def neo_load(node)
        Neography::Node.load(node)
      end
      
      def neo_node
        _neo_representation
      end
    
      def neo_destroy
        return unless neo_node
        Neoid.db.remove_node_from_index(neo_index_name, neo_node)
        neo_node.del
      end
    end
      
    def self.included(receiver)
      Neoid.db.create_node_index(receiver.name.tableize)
      
      receiver.extend         Neoid::ModelAdditions::ClassMethods
      receiver.send :include, Neoid::ModelAdditions::InstanceMethods
      receiver.extend         ClassMethods
      receiver.send :include, InstanceMethods
      
      receiver.neo_subref_node # ensure
      
      receiver.after_destroy :neo_destroy
    end
  end
end