require 'spec_helper'

describe Neoid::Relationship do
  let(:user) { User.create!(name: 'Elad Ossadon', slug: 'elado') }
  let(:movie) { Movie.create!(name: 'Memento', slug: 'memento-1999', year: 1999) }
  
  it 'should call neo_save after relationship model creation' do
    Like.any_instance.should_receive(:neo_save)
    user.like! movie
  end

  it 'should create a neo_relationship for like' do
    like = user.like! movie
    like = user.likes.last

    like.neo_find_by_id.should_not be_nil

    like.neo_relationship.should_not be_nil
    
    like.neo_relationship.start_node.should == user.neo_node
    like.neo_relationship.end_node.should == movie.neo_node
    like.neo_relationship.rel_type.should == 'likes'
  end
  
  it 'should delete a relationship on deleting a record' do
    user.like! movie
    like = user.likes.last
    
    relationship_neo_id = like.neo_relationship.neo_id

    Neography::Relationship.load(relationship_neo_id).should_not be_nil
    
    user.unlike! movie
    
    expect { Neography::Relationship.load(relationship_neo_id) }.to raise_error(Neography::RelationshipNotFoundException)
  end

  it 'should update neo4j on manual set of a collection' do
    movies = [
      Movie.create(name: 'Memento'),
      Movie.create(name: 'The Prestige'),
      Movie.create(name: 'The Dark Knight'),
      Movie.create(name: 'Spiderman')
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

  it 'should update a relationship after relationship model update' do
    like = user.like! movie

    like.neo_relationship.rate.should be_nil

    like.rate = 10
    like.save!

    like.neo_relationship.rate.should == 10
  end

  context 'polymorphic relationship' do
    let(:user) { User.create(name: 'Elad Ossadon', slug: 'elado') }

    it 'should create relationships with polymorphic items' do
      followed = [
        User.create(name: 'Some One', slug: 'someone'),
        Movie.create(name: 'The Prestige'),
        Movie.create(name: 'The Dark Knight')
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
