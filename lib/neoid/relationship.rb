module Neoid
  module Relationship
    module InstanceMethods
      def neo_find_by_id
        Neoid.db.get_relationship_index(self.class.neo_index_name, :ar_id, self.id)
      end
      
      def neo_create
        return unless Neoid.enabled?
        @_neo_destroyed = false
        
        options = self.class.neoid_config.relationship_options
        data = self.to_neo
        
        start_node = self.send(options[:start_node])
        end_node = self.send(options[:end_node])
        
        return unless start_node && end_node
        
        relationship = Neography::Relationship.create(
          options[:type].is_a?(Proc) ? options[:type].call(self) : options[:type],
          start_node.neo_node,
          end_node.neo_node,
          data.blank? ? nil : data
        )
        
        Neoid.db.add_relationship_to_index(self.class.neo_index_name, :ar_id, self.id, relationship)

        Neoid::logger.info "Relationship#neo_create #{self.class.name} #{self.id}, index = #{self.class.neo_index_name}"
        
        relationship
      end
      
      def neo_update
        Neoid.db.set_relationship_properties(neo_relationship, self.to_neo)
        
        neo_relationship
      end
      
      def neo_load(relationship)
        Neography::Relationship.load(relationship)
      end
      
      def neo_destroy
        return if @_neo_destroyed
        @_neo_destroyed = true
        return unless neo_relationship
        Neoid.db.remove_relationship_from_index(self.class.neo_index_name, neo_relationship)
        neo_relationship.del
        _reset_neo_representation

        Neoid::logger.info "Relationship#neo_destroy #{self.class.name} #{self.id}, index = #{self.class.neo_index_name}"

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
      receiver.after_update :neo_update
      receiver.after_destroy :neo_destroy

      if Neoid.env_loaded
        initialize_relationship receiver
      else
        Neoid.relationship_models << receiver
      end
    end

    def self.initialize_relationship(rel_model)
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
        # puts " CALLBACK SET #{belongs_to.klass.name} #{belongs_to.name} | #{full_callback_name} << :neo_after_relationship_remove"
        # belongs_to.klass.send(:has_many, this_has_many.name, this_has_many.options.merge(after_remove: :neo_after_relationship_remove))

        # has_many (with through) on the side of the relationship that removes a relationship. e.g. User has_many :movies, through :likes
        many_to_many = all_has_many.find { |o| o.options[:through] == this_has_many.name }
        next unless many_to_many

        return if many_to_many.options[:as] # polymorphic are not supported here yet

        # user_id
        foreign_key_of_owner = many_to_many.through_reflection.foreign_key

        # movie_id
        foreign_key_of_record = many_to_many.source_reflection.foreign_key

        (Neoid.config[:relationship_meta_data] ||= {}).tap do |data|
          (data[belongs_to.klass.name.to_s] ||= {}).tap do |model_data|
            model_data[many_to_many.klass.name.to_s] = [rel_model.name.to_s, foreign_key_of_owner, foreign_key_of_record]
          end
        end

        # puts Neoid.config[:relationship_meta_data].inspect

        # e.g. User has_many :movies, through: :likes, before_remove: ...
        full_callback_name = "before_remove_for_#{many_to_many.name}"
        belongs_to.klass.send(full_callback_name) << :neo_before_relationship_through_remove if belongs_to.klass.method_defined?(full_callback_name)
        # puts " CALLBACK SET #{belongs_to.klass.name} #{belongs_to.name} | #{full_callback_name} << :neo_before_relationship_through_remove"
        # belongs_to.klass.send(:has_many, many_to_many.name, many_to_many.options.merge(before_remove: :neo_after_relationship_remove))


        # e.g. User has_many :movies, through: :likes, after_remove: ...
        full_callback_name = "after_remove_for_#{many_to_many.name}"
        belongs_to.klass.send(full_callback_name) << :neo_after_relationship_through_remove if belongs_to.klass.method_defined?(full_callback_name)
        # puts " CALLBACK SET #{belongs_to.klass.name} #{belongs_to.name} | #{full_callback_name} << :neo_after_relationship_through_remove"
        # belongs_to.klass.send(:has_many, many_to_many.name, many_to_many.options.merge(after_remove: :neo_after_relationship_remove))
      end
    end
  end
end
