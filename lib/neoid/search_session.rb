module Neoid
  class SearchSession
    def initialize(response, model)
      @response = response || []
      @model = model
    end
    
    def hits
      @response.map { |x|
        Neography::Node.new(x)
      }
    end
    
    def results
      ids = @response.collect { |x| x['data']['ar_id'] }
      
      @model.where(id: ids)
    end
  end
end