module Neoid
  module Relationship
    class << self
      def from_hash(hash)
        relationship = RelationshipLazyProxy.new(hash)

        relationship
      end

      def included(receiver)
        receiver.send :include, Neoid::ModelAdditions
        receiver.send :include, InstanceMethods
        receiver.extend         ClassMethods

        initialize_relationship receiver if Neoid.env_loaded

        Neoid.relationship_models << receiver
      end

      def meta_data
        @meta_data ||= {}
      end

      def initialize_relationship(rel_model)
        rel_model.reflect_on_all_associations(:belongs_to).each do |belongs_to|
          return if belongs_to.options[:polymorphic]

          # e.g. all has_many on User class
          all_has_many = belongs_to.klass.reflect_on_all_associations(:has_many)

          # has_many (without through) on the side of the relationship that removes a relationship. e.g. User has_many :likes
          this_has_many = all_has_many.find { |o| o.klass == rel_model }
          next unless this_has_many

          # e.g. User has_many :likes, after_remove: ...
          full_callback_name = "after_remove_for_#{this_has_many.name}"
          belongs_to.klass.send(full_callback_name) << :neo_after_relationship_remove if belongs_to.klass.method_defined?(full_callback_name)

          # has_many (with through) on the side of the relationship that removes a relationship. e.g. User has_many :movies, through :likes
          many_to_many = all_has_many.find { |o| o.options[:through] == this_has_many.name }
          next unless many_to_many

          return if many_to_many.options[:as] # polymorphic are not supported here yet

          # user_id
          foreign_key_of_owner = many_to_many.through_reflection.foreign_key

          # movie_id
          foreign_key_of_record = many_to_many.source_reflection.foreign_key

          (Neoid::Relationship.meta_data ||= {}).tap do |data|
            (data[belongs_to.klass.name.to_s] ||= {}).tap do |model_data|
              model_data[many_to_many.klass.name.to_s] = [rel_model.name.to_s, foreign_key_of_owner, foreign_key_of_record]
            end
          end

          # e.g. User has_many :movies, through: :likes, before_remove: ...
          full_callback_name = "before_remove_for_#{many_to_many.name}"
          belongs_to.klass.send(full_callback_name) << :neo_before_relationship_through_remove if belongs_to.klass.method_defined?(full_callback_name)

          # e.g. User has_many :movies, through: :likes, after_remove: ...
          full_callback_name = "after_remove_for_#{many_to_many.name}"
          belongs_to.klass.send(full_callback_name) << :neo_after_relationship_through_remove if belongs_to.klass.method_defined?(full_callback_name)
        end
      end
    end

    # this is a proxy that delays loading of start_node and end_node from Neo4j until accessed.
    # the original Neography Relatioship loaded them on initialization
    class RelationshipLazyProxy < ::Neography::Relationship
      def start_node
        @start_node_from_db ||= @start_node = Neography::Node.load(@start_node, Neoid.db)
      end

      def end_node
        @end_node_from_db ||= @end_node = Neography::Node.load(@end_node, Neoid.db)
      end
    end

    module ClassMethods
      def delete_command
        :delete_relationship
      end
    end

    module InstanceMethods
      def neo_find_by_id
        results = Neoid.db.get_relationship_auto_index(Neoid::UNIQUE_ID_KEY, neo_unique_id)
        relationship = results.present? ? Neoid::Relationship.from_hash(results[0]) : nil
        relationship
      end

      def _neo_save
        return unless Neoid.enabled?

        options = self.class.neoid_config.relationship_options

        start_item = send(options[:start_node])
        end_item = send(options[:end_node])

        return unless start_item && end_item

        # initialize nodes
        start_item.neo_node
        end_item.neo_node

        data = to_neo.merge(ar_type: self.class.name, ar_id: id, Neoid::UNIQUE_ID_KEY => neo_unique_id)
        data.reject! { |k, v| v.nil? }

        rel_type = options[:type].is_a?(Proc) ? options[:type].call(self) : options[:type]

        gremlin_query = <<-GREMLIN
          idx = g.idx('relationship_auto_index');
          q = null;
          if (idx) q = idx.get(unique_id_key, unique_id);

          relationship = null;
          if (q && q.hasNext()) {
            relationship = q.next();
            relationship_data.each {
              if (relationship.getProperty(it.key) != it.value) {
                relationship.setProperty(it.key, it.value);
              }
            }
          } else {
            node_index = g.idx('node_auto_index');
            start_node = node_index.get(unique_id_key, start_node_unique_id).next();
            end_node = node_index.get(unique_id_key, end_node_unique_id).next();

            relationship = g.addEdge(start_node, end_node, rel_type, relationship_data);
          }

          relationship
        GREMLIN

        script_vars = {
          unique_id_key: Neoid::UNIQUE_ID_KEY,
          relationship_data: data,
          unique_id: neo_unique_id,
          start_node_unique_id: start_item.neo_unique_id,
          end_node_unique_id: end_item.neo_unique_id,
          rel_type: rel_type
        }

        Neoid::logger.info "Relationship#neo_save #{self.class.name} #{id}"

        relationship = Neoid.execute_script_or_add_to_batch gremlin_query, script_vars do |value|
          Neoid::Relationship.from_hash(value)
        end

        relationship
      end

      def neo_load(hash)
        Neoid::Relationship.from_hash(hash)
      end

      def neo_relationship
        _neo_representation
      end
    end
  end
end
