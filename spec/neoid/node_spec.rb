require 'spec_helper'

describe Neoid::Node do
  context 'create graph nodes' do
    it 'should call neo_save after model creation' do
      user = User.new(name: 'Elad Ossadon')
      expect(user).to receive(:neo_save)
      user.save!
    end

    it 'should create a node for user' do
      user = User.create!(name: 'Elad Ossadon', slug: 'elado')

      expect(user.neo_node).to_not be_nil

      expect(user.neo_node.ar_id).to eq(user.id)
      expect(user.neo_node.name).to eq(user.name)
      expect(user.neo_node.slug).to eq(user.slug)
    end

    it 'should create a neo_node for movie' do
      movie = Movie.create!(name: 'Memento', slug: 'memento-1999', year: 1999)

      expect(movie.neo_node).to_not be_nil

      expect(movie.neo_node.ar_id).to eq(movie.id)
      expect(movie.neo_node.name).to eq(movie.name)
      expect(movie.neo_node.year).to eq(movie.year)
    end
  end

  context 'update graph nodes' do
    it 'should call neo_save after model update' do
      user = User.create!(name: 'Elad Ossadon')
      expect(user).to receive(:neo_save)
      user.name = 'John Doe'
      user.save!
    end

    it 'should update a node after model update' do
      user = User.create!(name: 'Elad Ossadon')
      expect(user.neo_node.name).to eq('Elad Ossadon')

      user.name = 'John Doe'
      user.save!

      expect(user.neo_node.name).to eq('John Doe')
    end
  end

  context 'find by id' do
    it 'should find a neo_node for user' do
      user = User.create!(name: 'Elad Ossadon', slug: 'elado')

      expect(user.neo_node).to_not be_nil
      expect(user.neo_find_by_id).to_not be_nil
    end
  end

  context 'no auto_index' do
    it 'should not index a node if option :auto_index is set to false' do
      model = NoAutoIndexNode.new(name: 'Hello')
      expect(model).to_not receive(:neo_save)
      model.save!
    end
  end

  context 'subrefs' do
    it 'should connect subrefs to reference node' do
      pending
      old, Neoid.config.enable_subrefs = Neoid.config.enable_subrefs, true

      Neoid.send(:initialize_subrefs)

      begin
        Neoid.ref_node.rel(:outgoing, :users_subref).should_not be_nil
      ensure
        Neoid.config.enable_subrefs = old
      end
    end

    it 'should create a relationship with a subref node' do
      pending
      old, Neoid.config.enable_subrefs = Neoid.config.enable_subrefs, true

      Neoid.send(:initialize_subrefs)

      begin
        user = User.create!(name: 'Elad')
        user.neo_node.rel(:incoming, :users).should_not be_nil
      ensure
        Neoid.config.enable_subrefs = old
      end
    end

    it 'should not create a relationship with a subref node if disabled' do
      pending
      old, Neoid.config.enable_subrefs = Neoid.config.enable_subrefs, false

      begin
        user = User.create!(name: 'Elad')
        expect(user.neo_node.rel(:incoming, :users_subref)).to be_nil
      ensure
        Neoid.config.enable_subrefs = old
      end
    end
  end

  context 'per_model_indexes' do
    it 'should create a relationship with a subref node' do
      old, Neoid.config.enable_per_model_indexes = Neoid.config.enable_per_model_indexes, true

      Neoid.send(:initialize_per_model_indexes)

      begin
        user = User.create!(name: 'Elad')
        expect(Neoid.db.get_node_index(User.neo_model_index_name, 'ar_id', user.id)).to_not be_nil
      ensure
        Neoid.config.enable_per_model_indexes = old
      end
    end

    it 'should not create a relationship with a subref node if disabled' do
      old, Neoid.config.enable_per_model_indexes = Neoid.config.enable_per_model_indexes, false

      begin
        user = User.create!(name: 'Elad')
        expect { Neoid.db.get_node_index(User.neo_model_index_name, 'ar_id', user.id) }.to raise_error(Neography::NotFoundException)
      ensure
        Neoid.config.enable_per_model_indexes = old
      end
    end
  end
end
