require 'spec_helper'

describe Neoid::Config do
  context 'config' do
    it 'should store and read config' do
      Neoid.configure do |config|
        config.enable_subrefs = false
      end

      Neoid.config.enable_subrefs.should == false
    end
  end
end
