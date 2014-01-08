require 'spec_helper'

describe Neoid do
  context "connection" do
    it "should use the default connection when none explicitly set" do
      default = Neoid.default_connection_name
      default.should be

      Like.neo4j_connection.should eq Neoid.connection(default)
    end

    it "should use the given connection when one IS explicitly set" do
      # NOTE: The user model (in support/models) is hard-coded to use the
      # 'main' connection, for this test.
      User.neo4j_connection.should eq Neoid.connection(:main)
    end
  end
end
