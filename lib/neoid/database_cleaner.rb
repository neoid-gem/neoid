module Neoid
  class NeoDatabaseCleaner
    def self.clean_db(instance, start_node = nil)
      #start_node ||= instance.db.get_root
      instance.db.execute_query <<-CYPHER
        START n0=node(0),nx=node(*) OPTIONAL MATCH n0-[r0]-(),nx-[rx]-() WHERE nx <> n0 DELETE r0,rx,nx
      CYPHER

      true
    end
  end
end
