require 'spec_helper'

describe Neoid::Node do
  subject(:user) { User.create!(name: 'Elad Ossadon', slug: 'elado') }

  context 'creates' do
    its(:neo_node) { should_not be_nil }
    its('neo_node.ar_id') { should eq(user.id) }
    its('neo_node.name') { should eq(user.name) }
    its('neo_node.slug') { should eq(user.slug) }

    describe '.neo_save' do
      let(:user) { User.new(name: 'Elad Ossadon') }

      it 'will call .neo_save' do
        expect(user).to receive(:neo_save)
        user.save!
      end
    end

    describe '#auto_index' do
      subject(:node) { NoAutoIndexNode.new(name: 'Hello') }
      
      it { should_not receive(:neo_save) }
    end
  end

  context 'reads' do
    its(:neo_find_by_id) { should_not be_nil }
  end

  context 'updates' do
    before(:each) do
      user.name = 'John Doe'
    end

    it 'will call .neo_save' do
      expect(user).to receive(:neo_save)
      user.save!
    end

    it 'will update a node' do
      user.save!
      expect(user.neo_node.name).to eq('John Doe')
    end
  end

  context 'per_model_indexes' do
    before(:each) do
      Neoid.config.enable_per_model_indexes = false
    end

    it 'should create a relationship with a subref node' do
      Neoid.config.enable_per_model_indexes = true
      Neoid.send(:initialize_per_model_indexes)

      begin
        expect(Neoid.db.get_node_index(User.neo_model_index_name, 'ar_id', user.id)).to_not be_nil
      ensure
        Neoid.config.enable_per_model_indexes = false
      end
    end

    it 'should not create a relationship with a subref node if disabled' do
      begin
        expect { Neoid.db.get_node_index(User.neo_model_index_name, 'ar_id', user.id) }.to raise_error(Neography::NotFoundException)
      ensure
        Neoid.config.enable_per_model_indexes = true
      end
    end
  end

  # Currently, all subref tests are failing.
  # They have been placed as pending until they have been fixed.
  # Apologies.
  context 'subrefs' do
    it 'should connect subrefs to reference node' do
      pending 'currently failing'
      old, Neoid.config.enable_subrefs = Neoid.config.enable_subrefs, true

      Neoid.send(:initialize_subrefs)

      begin
        Neoid.ref_node.rel(:outgoing, :users_subref).should_not be_nil
      ensure
        Neoid.config.enable_subrefs = old
      end
    end

    it 'should create a relationship with a subref node' do
      pending 'currently failing'
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
      pending 'currently failing'
      old, Neoid.config.enable_subrefs = Neoid.config.enable_subrefs, false

      begin
        user = User.create!(name: 'Elad')
        expect(user.neo_node.rel(:incoming, :users_subref)).to be_nil
      ensure
        Neoid.config.enable_subrefs = old
      end
    end
  end
end
