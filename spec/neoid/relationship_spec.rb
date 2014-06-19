require 'spec_helper'

describe Neoid::Relationship do
  let(:user) { User.create!(name: 'Elad Ossadon', slug: 'elado') }
  let(:movie) { Movie.create!(name: 'Memento', slug: 'memento-1999', year: 1999) }

  it 'should call neo_save after relationship model creation' do
    expect_any_instance_of(Like).to receive(:neo_save)
    user.like! movie
  end

  it 'should create a neo_relationship for like' do
    like = user.like! movie
    like = user.likes.last

    expect(like.neo_find_by_id).to_not be_nil

    expect(like.neo_relationship).to_not be_nil

    expect(like.neo_relationship.start_node).to eq(user.neo_node)
    expect(like.neo_relationship.end_node).to eq(movie.neo_node)
    expect(like.neo_relationship.rel_type).to eq('likes')
  end

  it 'should delete a relationship on deleting a record' do
    user.like! movie
    like = user.likes.last

    relationship_neo_id = like.neo_relationship.neo_id

    expect(Neography::Relationship.load(relationship_neo_id)).to_not be_nil

    user.unlike! movie

    expect { Neography::Relationship.load(relationship_neo_id) }.to raise_error(Neography::RelationshipNotFoundException)
  end

  it 'should update neo4j on manual set of a collection' do
    pending
    movies = [
      Movie.create(name: 'Memento'),
      Movie.create(name: 'The Prestige'),
      Movie.create(name: 'The Dark Knight'),
      Movie.create(name: 'Spiderman')
    ]

    expect(user.neo_node.outgoing(:likes).length).to eq(0)

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
      user.movie_ids = movies[0...2].map(&:id)
    }.to change{ user.neo_node.outgoing(:likes).length }.to(2)
  end

  it 'should update a relationship after relationship model update' do
    like = user.like! movie

    expect(like.neo_relationship.rate).to be_nil

    like.rate = 10
    like.save!

    expect(like.neo_relationship.rate).to eq(10)
  end

  context 'polymorphic relationship' do
    let(:user) { User.create(name: 'Elad Ossadon', slug: 'elado') }

    it 'should create relationships with polymorphic items' do
      pending
      followed = [
        User.create(name: 'Some One', slug: 'someone'),
        Movie.create(name: 'The Prestige'),
        Movie.create(name: 'The Dark Knight')
      ]

      expect {
        followed.each do |item|
          user.user_follows.create!(item: item)
        end
      }.to change { user.neo_node.outgoing(:follows).length }.to(followed.length)

      expect {
        user.user_follows = user.user_follows[0...1]
      }.to change { user.neo_node.outgoing(:follows).length }.to(1)

      expect {
        user.user_follows = []
      }.to change { user.neo_node.outgoing(:follows).length }.to(0)
    end
  end
end
