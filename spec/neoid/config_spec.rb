require 'spec_helper'

describe Neoid::Config do
  context "config" do
    it "should store and read config" do
      Neoid.connection.configure do |config|
        config.enable_subrefs = false
      end

      Neoid.connection.config.enable_subrefs.should == false
    end
  end
end
