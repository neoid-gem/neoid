require 'spec_helper'

describe Neoid do
  context 'subrefs' do
    before(:each) do
      # first we have to enable subrefs
      Neoid.config.enable_subrefs = true
      # now that its enabled, we re-initialize the module
      Neoid.initialize_all
    end

    it 'should create all subrefs on initialization' do
      Neoid.node_models.each do |klass|
        expect(klass.instance_variable_get(:@neo_subref_node)).to_not be_nil
      end
    end
  end
end
