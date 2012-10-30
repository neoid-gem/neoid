module Neoid
  class NeoDatabaseCleaner
    def self.clean_db(start_node = Neoid.db.get_root)
      Neoid.db.execute_script <<-GREMLIN
        g.V.toList().each { if (it.id != 0) g.removeVertex(it) }
        g.indices.each { g.dropIndex(it.indexName); }
      GREMLIN

      true
    end
  end
end
