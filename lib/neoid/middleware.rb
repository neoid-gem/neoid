module Neoid
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      old_enabled, Thread.current[:neoid_enabled] = Thread.current[:neoid_enabled], true
      old_batch, Thread.current[:neoid_current_batch] = Thread.current[:neoid_current_batch], nil
      @app.call(env)
    ensure
      Thread.current[:neoid_enabled] = old_enabled
      Thread.current[:neoid_current_batch] = old_batch
    end
  end
end
