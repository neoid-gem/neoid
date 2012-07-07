require 'spec_helper'
require 'fileutils'

describe Neoid::ModelAdditions do
  context "nodes" do
    context "create graph nodes" do
      it "should call neo_create on a neo_node for user" do
        User.any_instance.should_receive(:neo_create)

        User.create(name: "Elad Ossadon")
      end
  
      it "should create a neo_node for user" do
        user = User.create(name: "Elad Ossadon", slug: "elado")
      
        user.neo_node.should_not be_nil
        
        user.neo_node.ar_id.should == user.id
        user.neo_node.name.should == user.name
        user.neo_node.slug.should == user.slug
      end

      it "should create a neo_node for movie" do
        movie = Movie.create(name: "Memento", slug: "memento-1999", year: 1999)
      
        movie.neo_node.should_not be_nil
        
        movie.neo_node.ar_id.should == movie.id
        movie.neo_node.name.should == movie.name
        movie.neo_node.year.should == movie.year
      end
    end
  
    context "find by id" do
      it "should find a neo_node for user" do
        user = User.create(name: "Elad Ossadon", slug: "elado")
      
        user.neo_node.should_not be_nil
        user.neo_find_by_id.should_not be_nil
      end
    end
  end
  
  context "relationships" do
    let(:user) { User.create(name: "Elad Ossadon", slug: "elado") }
    let(:movie) { Movie.create(name: "Memento", slug: "memento-1999", year: 1999) }
    
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
      like = user.likes.last
      
      relationship_neo_id = like.neo_relationship.neo_id
      
      Neography::Relationship.load(relationship_neo_id).should_not be_nil
      
      user.unlike! movie
      
      Neography::Relationship.load(relationship_neo_id).should be_nil
    end

    it "should update neo4j on manual set of a collection" do
      movies = [
        Movie.create(name: "Memento"),
        Movie.create(name: "The Prestige"),
        Movie.create(name: "The Dark Knight"),
        Movie.create(name: "Spiderman")
      ]

      user.neo_node.outgoing(:likes).length.should == 0

      expect {
        user.movies = movies
      }.to change{ user.neo_node.outgoing(:likes).length }.to(movies.length)

      expect { expect {
        user.movies -= movies[0..1]
      }.to change{ user.movies.count }.by(-2)
      }.to change{ user.neo_node.outgoing(:likes).length }.by(-2)

      expect {
        user.movies = []
      }.to change{ user.neo_node.outgoing(:likes).length }.to(0)

      expect {
        user.movie_ids = movies[0...2].collect(&:id)
      }.to change{ user.neo_node.outgoing(:likes).length }.to(2)
    end
  end

  context "polymorphic relationship" do
    let(:user) { User.create(name: "Elad Ossadon", slug: "elado") }

    it "description" do
      followed = [
        User.create(name: "Some One", slug: "someone"),
        Movie.create(name: "The Prestige"),
        Movie.create(name: "The Dark Knight")
      ]

      expect {
        followed.each do |item|
          user.user_follows.create(item: item)
        end
      }.to change{ user.neo_node.outgoing(:follows).length }.to(followed.length)

      expect {
        user.user_follows = user.user_follows[0...1]
      }.to change{ user.neo_node.outgoing(:follows).length }.to(1)

      expect {
        user.user_follows = []
      }.to change{ user.neo_node.outgoing(:follows).length }.to(0)
    end
  end
end
