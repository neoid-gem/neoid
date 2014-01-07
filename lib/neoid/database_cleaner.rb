module Neoid
  class NeoDatabaseCleaner
    def self.clean_db(instance, start_node = nil)
      start_node ||= instance.db.get_root
      instance.db.execute_script <<-GREMLIN
        g.V.toList().each { if (it.id != 0) g.removeVertex(it) }
        g.indices.each { g.dropIndex(it.indexName); }
      GREMLIN

      true
    end
  end
end
