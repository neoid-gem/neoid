require 'spec_helper'

describe Neoid do
  context "subrefs" do
    it "should create all subrefs on initialization" do
      Neoid.connection.node_models.each do |klass|
        klass.instance_variable_get(:@neo_subref_node).should_not be_nil
      end
    end
  end
end
