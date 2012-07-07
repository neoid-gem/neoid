module Neoid
  class Railtie < Rails::Railtie
    initializer "neoid.configure_rails_initialization" do
      config.after_initialize do
        Neoid.initialize_all
      end
    end
  end
end
