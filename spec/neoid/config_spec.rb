require 'spec_helper'

describe Neoid::Config do
  subject(:config) { Neoid.config }

  describe '.enable_subrefs' do
    before(:all) do
      Neoid.configure { |c| c.enable_subrefs = false }
    end

    its(:enable_subrefs) { should == false }
  end
end
