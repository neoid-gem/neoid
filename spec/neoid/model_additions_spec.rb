require 'spec_helper'

describe Neoid::ModelAdditions do
  context "nodes" do
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
      it "should create a relationship with a subref node" do
        old, Neoid.config.enable_subrefs = Neoid.config.enable_subrefs, true

        Neoid.send(:initialize_subrefs)
        
        begin
          user = User.create!(name: "Elad")
          user.neo_node.rel(:incoming, :users_subref).should_not be_nil
        ensure
          Neoid.config.enable_subrefs = old
        end
      end

      it "should not create a relationship with a subref node if disabled" do
        old, Neoid.config.enable_subrefs = Neoid.config.enable_subrefs, false

        begin
          user = User.create!(name: "Elad")
          user.neo_node.rel(:incoming, :users_subref).should be_nil
        ensure
          Neoid.config.enable_subrefs = old
        end
      end
    end

    context "per_model_indexes" do
      it "should create a relationship with a subref node" do
        old, Neoid.config.enable_per_model_indexes = Neoid.config.enable_per_model_indexes, true

        Neoid.send(:initialize_per_model_indexes)

        begin
          user = User.create!(name: "Elad")
          Neoid.db.get_node_index(User.neo_model_index_name, 'ar_id', user.id).should_not be_nil
        ensure
          Neoid.config.enable_per_model_indexes = old
        end
      end

      it "should not create a relationship with a subref node if disabled" do
        old, Neoid.config.enable_per_model_indexes = Neoid.config.enable_per_model_indexes, false

        begin
          user = User.create!(name: "Elad")
          expect { Neoid.db.get_node_index(User.neo_model_index_name, 'ar_id', user.id) }.to raise_error(Neography::NotFoundException)
        ensure
          Neoid.config.enable_per_model_indexes = old
        end
      end
    end
  end
  
  context "relationships" do
    let(:user) { User.create!(name: "Elad Ossadon", slug: "elado") }
    let(:movie) { Movie.create!(name: "Memento", slug: "memento-1999", year: 1999) }
    
    it "should call neo_save after relationship model creation" do
      Like.any_instance.should_receive(:neo_save)
      user.like! movie
    end

    it "should create a neo_relationship for like" do
      like = user.like! movie
      like = user.likes.last

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
      
      expect { Neography::Relationship.load(relationship_neo_id) }.to raise_error(Neography::RelationshipNotFoundException)
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

    it "should update a relationship after relationship model update" do
      like = user.like! movie

      like.neo_relationship.rate.should be_nil

      like.rate = 10
      like.save!

      like.neo_relationship.rate.should == 10
    end
  end

  context "polymorphic relationship" do
    let(:user) { User.create(name: "Elad Ossadon", slug: "elado") }

    it "should create relationships with polymorphic items" do
      followed = [
        User.create(name: "Some One", slug: "someone"),
        Movie.create(name: "The Prestige"),
        Movie.create(name: "The Dark Knight")
      ]

      expect {
        followed.each do |item|
          user.user_follows.create!(item: item)
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
