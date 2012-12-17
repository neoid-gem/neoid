module Ndoid
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      old, Thread.current[:neoid_enabled] = Thread.current[:neoid_enabled], true
      @app.call(env)
    ensure
      Thread.current[:neoid_enabled] = old
    end
  end
end
