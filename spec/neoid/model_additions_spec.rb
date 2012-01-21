require 'spec_helper'

class User < SuperModel::Base
  include ActiveModel::Validations::Callbacks
  
  has_many :likes
  has_many :movies, through: :likes
  
  
  # _test_movies is here because SuperModel doesn't handle has_many queries
  # it simulates the database. see comments in each method to see a regular AR implementation
  def _test_movies
    @_test_movies ||= []
  end
  
  def likes?(movie)
    # likes.where(movie_id: movie.id).exists?
    _test_movies.any? { |it| it.movie_id == movie.id }
  end
  
  def like!(movie)
    # movies << movie unless likes?(movie)
    _test_movies << Like.create(user_id: self.id, movie_id: movie.id) unless likes?(movie)
  end
  
  def unlike!(movie)
    # likes.where(movie_id: movie.id, user_id: self.id).destroy_all
    _test_movies.delete_if { |it| it.destroy if it.movie_id == movie.id }
  end
  
  include Neoid::Node
  
  def to_neo
    neo_properties_to_hash(%w( name slug ))
  end
end

class Movie < SuperModel::Base
  include ActiveModel::Validations::Callbacks
  
  has_many :likes
  has_many :users, through: :likes
  
  include Neoid::Node

  def to_neo
    neo_properties_to_hash(%w( name slug year ))
  end
end

class Like < SuperModel::Base
  include ActiveModel::Validations::Callbacks
  
  belongs_to :user
  belongs_to :movie
  
  include Neoid::Relationship
  
  neoidable start_node: :user, end_node: :movie, type: :likes

  def to_neo
    neo_properties_to_hash(%w( rate ))
  end
end

require 'spec_helper'
require 'fileutils'

describe Neoid::ModelAdditions do
  before(:each) do
    [ User, Movie ].each { |klass|
      klass.instance_variable_set(:@_neo_subref_node, nil)
    }
    Neoid.ref_node = nil
  end
  
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
      like = user.likes.first
      
      relationship_neo_id = like.neo_relationship.neo_id
      
      Neography::Relationship.load(relationship_neo_id).should_not be_nil
      
      user.unlike! movie
      
      Neography::Relationship.load(relationship_neo_id).should be_nil
    end
  end
end
