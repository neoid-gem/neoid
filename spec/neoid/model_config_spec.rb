require 'spec_helper'
require 'fileutils'


describe Neoid::ModelConfig do
  context "config on a model" do
    it "should store search fields" do
      class Article1 < SuperModel::Base
        include ActiveModel::Validations::Callbacks
        include Neoid::Node
        neoidable do |c|
          c.search do |s|
            s.index :name
            s.index :year
          end
        end
      end
      
      Article1.neoid_config.search_options.should_not be_nil
      Article1.neoid_config.search_options.index_fields.keys.should =~ [ :name, :year ]
    end

    it "should store stored fields" do
      class Article2 < SuperModel::Base
        include ActiveModel::Validations::Callbacks
        include Neoid::Node
        neoidable do |c|
          c.field :name
          c.field :year
        end
      end

      Article2.neoid_config.stored_fields.should_not be_nil
      Article2.neoid_config.stored_fields.should =~ [ :name, :year ]
    end
  end
end
