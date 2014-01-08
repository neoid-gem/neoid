require 'spec_helper'

describe Neoid::Node do
  context "create graph nodes" do
    it "should call neo_save after model creation" do
      user = User.new(name: "Elad Ossadon")
      user.should_receive(:neo_save)
      user.save!
    end

    it "should create a node for user" do
      user = User.create!(name: "Elad Ossadon", slug: "elado")

      user.neo_node.should_not be_nil
      
      user.neo_node.ar_id.should == user.id
      user.neo_node.name.should == user.name
      user.neo_node.slug.should == user.slug
    end

    it "should create a neo_node for movie" do
      movie = Movie.create!(name: "Memento", slug: "memento-1999", year: 1999)

      movie.neo_node.should_not be_nil
      
      movie.neo_node.ar_id.should == movie.id
      movie.neo_node.name.should == movie.name
      movie.neo_node.year.should == movie.year
    end
  end

  context "update graph nodes" do
    it "should call neo_save after model update" do
      user = User.create!(name: "Elad Ossadon")
      user.should_receive(:neo_save)
      user.name = "John Doe"
      user.save!
    end

    it "should update a node after model update" do
      user = User.create!(name: "Elad Ossadon")
      user.neo_node.name.should == "Elad Ossadon"

      user.name = "John Doe"
      user.save!

      user.neo_node.name.should == "John Doe"
    end
  end

  context "find by id" do
    it "should find a neo_node for user" do
      user = User.create!(name: "Elad Ossadon", slug: "elado")
      
      user.neo_node.should_not be_nil
      user.neo_find_by_id.should_not be_nil
    end
  end

  context "no auto_index" do
    it "should not index a node if option :auto_index is set to false" do
      model = NoAutoIndexNode.new(name: "Hello")
      model.should_not_receive(:neo_save)
      model.save!
    end
  end

  context "subrefs" do
    it "should connect subrefs to reference node" do
      old, Neoid.connection.config.enable_subrefs = Neoid.connection.config.enable_subrefs, true

      Neoid.connection.send(:initialize_subrefs)
      
      begin
        Neoid.connection.ref_node.rel(:outgoing, :users_subref).should_not be_nil
      ensure
        Neoid.connection.config.enable_subrefs = old
      end
    end

    it "should create a relationship with a subref node" do
      old, Neoid.connection.config.enable_subrefs = Neoid.connection.config.enable_subrefs, true

      Neoid.connection.send(:initialize_subrefs)
      
      begin
        user = User.create!(name: "Elad")
        user.neo_node.rel(:incoming, :users).should_not be_nil
      ensure
        Neoid.connection.config.enable_subrefs = old
      end
    end

    it "should not create a relationship with a subref node if disabled" do
      old, Neoid.connection.config.enable_subrefs = Neoid.connection.config.enable_subrefs, false

      begin
        user = User.create!(name: "Elad")
        user.neo_node.rel(:incoming, :users_subref).should be_nil
      ensure
        Neoid.connection.config.enable_subrefs = old
      end
    end
  end

  context "per_model_indexes" do
    it "should create a relationship with a subref node" do
      old, Neoid.connection.config.enable_per_model_indexes = Neoid.connection.config.enable_per_model_indexes, true

      Neoid.connection.send(:initialize_per_model_indexes)

      begin
        user = User.create!(name: "Elad")
        Neoid.connection.db.get_node_index(User.neo_model_index_name, 'ar_id', user.id).should_not be_nil
      ensure
        Neoid.connection.config.enable_per_model_indexes = old
      end
    end

    it "should not create a relationship with a subref node if disabled" do
      old, Neoid.connection.config.enable_per_model_indexes = Neoid.connection.config.enable_per_model_indexes, false

      begin
        user = User.create!(name: "Elad")
        expect { Neoid.connection.db.get_node_index(User.neo_model_index_name, 'ar_id', user.id) }.to raise_error(Neography::NotFoundException)
      ensure
        Neoid.connection.config.enable_per_model_indexes = old
      end
    end
  end
end
