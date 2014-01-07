require 'neoid/middleware'

module Neoid
  class Railtie < Rails::Railtie
    initializer "neoid.configure_rails_initialization" do
      config.after_initialize do
        Neoid.initialize_all
      end
    end

    initializer 'neoid.inject_middleware' do |app|
      app.middleware.use Ndoid::Middleware
    end
  end
end
