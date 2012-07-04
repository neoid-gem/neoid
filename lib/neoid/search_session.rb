module Neoid
  class SearchSession
    def initialize(response, *models)
      @response = response || []
      @models = models
    end
    
    def hits
      @response.map { |x|
        Neography::Node.new(x)
      }
    end

    def ids
      @response.collect { |x| x['data']['ar_id'] }
    end
    
    def results
      models_by_name = @models.inject({}) { |all, curr| all[curr.name] = curr; all }

      ids_by_klass = @response.inject({}) { |all, curr|
        klass_name = curr['data']['ar_type']
        (all[models_by_name[klass_name]] ||= []) << curr['data']['ar_id']
        all
      }

      ids_by_klass.map { |klass, ids| klass.where(id: ids) }.flatten
    end
  end
end
