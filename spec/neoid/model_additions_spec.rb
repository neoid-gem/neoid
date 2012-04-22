require 'spec_helper'
require 'fileutils'

describe Neoid::ModelAdditions do
  context "nodes" do
    context "create graph nodes" do
      it "should call neo_create on a neo_node for user" do
        User.any_instance.should_receive(:neo_create)

        User.create(:name=> "Elad Ossadon")
      end

      it "should create a neo_node for user" do
        user = User.create(:name=> "Elad Ossadon", :slug=> "elado")

        user.neo_node.should_not be_nil

        user.neo_node.ar_id.should == user.id
        user.neo_node.name.should == user.name
        user.neo_node.slug.should == user.slug
      end

      it "should create a neo_node for movie" do
        movie = Movie.create(:name=> "Memento", :slug=> "memento-1999", :year=> 1999)

        movie.neo_node.should_not be_nil

        movie.neo_node.ar_id.should == movie.id
        movie.neo_node.name.should == movie.name
        movie.neo_node.year.should == movie.year
      end
    end

    context "find by id" do
      it "should find a neo_node for user" do
        user = User.create(:name=> "Elad Ossadon", :slug=> "elado")

        user.neo_node.should_not be_nil
        user.neo_find_by_id.should_not be_nil
      end
    end
  end

  context "relationships" do
    let(:user) { User.create(:name=> "Elad Ossadon", :slug=> "elado") }
    let(:movie) { Movie.create(:name=> "Memento", :slug=> "memento-1999", :year=> 1999) }

    it "should create a relationship on neo4j" do
      user.like! movie
      like = user.likes.first

      like.neo_find_by_id.should_not be_nil

      like.neo_relationship.should_not be_nil

      like.neo_relationship.start_node.should == user.neo_node
      like.neo_relationship.end_node.should == movie.neo_node
      like.neo_relationship.rel_type.should == 'likes'
    end

    it "should delete a relationship on deleting a record" do
      user.like! movie
      like = user.likes.first

      relationship_neo_id = like.neo_relationship.neo_id

      Neography::Relationship.load(relationship_neo_id).should_not be_nil

      user.unlike! movie

      Neography::Relationship.load(relationship_neo_id).should be_nil
    end
  end
end
