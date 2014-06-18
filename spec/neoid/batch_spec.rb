require 'spec_helper'

describe Neoid::ModelAdditions do
  context 'promises' do
    it 'should run scripts in a batch and return results' do
      Neoid.batch do |batch|
        batch << [:execute_script, '1']
        batch << [:execute_script, '2']
      end.then do |results|
        results.map do |result|
          result['body']
        end.should == [1, 2]
      end
    end

    it 'should run scripts in a batch with batch_size and flush batch when it\'s full' do
      Neoid.batch(batch_size: 3) do |batch|
        (0...9).each do |i|
          batch.count.should == i % 3
          batch << [:execute_script, i.to_s]
          if i % 3 == 0
            batch.results.count.should == i
          end
        end
      end
    end

    it 'should run scripts in a batch with batch_size and return all results' do
      Neoid.batch(batch_size: 2) do |batch|
        (1..6).each do |i|
          batch << [:execute_script, i.to_s]
        end
      end.then do |results|
        results.map do |result|
          result['body']
        end.should == [1, 2, 3, 4, 5, 6]
      end
    end

    it 'should return results then process them' do
      node_1 = Neoid.db.create_node
      node_2 = Neoid.db.create_node
      rel = Neoid.db.create_relationship(:related, node_1, node_2)

      Neoid.batch do |batch|
        batch << [:execute_script, 'g.v(neo_id)', neo_id: node_1['self'].split('/').last.to_i]
        batch << [:execute_script, 'g.v(neo_id)', neo_id: node_2['self'].split('/').last]
        batch << [:execute_script, 'g.e(neo_id)', neo_id: rel['self'].split('/').last]
      end.then do |results|
        results[0].should be_a(Neography::Node)
        results[1].should be_a(Neography::Node)
        results[2].should be_a(Neography::Relationship)
      end
    end

    it 'should remember what to do after each script has executed, and perform it when batch is flushed' do
      then_results = []

      Neoid.batch do |batch|
        (batch << [:execute_script, '1']).then { |res| then_results << res }
        (batch << [:execute_script, '2']).then { |res| then_results << res }
        batch << [:execute_script, '3']
        (batch << [:execute_script, '4']).then { |res| then_results << res }
      end.then do |results|
        results.map do |result|
          result['body'].should == [1, 2, 3, 4]
        end
        then_results.should == [1, 2, 4]
      end
    end
  end

  context 'nodes' do
    it 'should not execute until batch is done' do
      u1 = u2 = nil

      res = Neoid.batch do
        u1 = User.create!(name: 'U1')
        u2 = User.create!(name: 'U2')

        u1.neo_find_by_id.should be_nil
        u2.neo_find_by_id.should be_nil
      end

      res.length.should == 2

      u1.neo_find_by_id.should_not be_nil
      u2.neo_find_by_id.should_not be_nil
    end

    it 'should update nodes in batch' do
      u1 = User.create!(name: 'U1')
      u2 = User.create!(name: 'U2')

      res = Neoid.batch do
        u1.name = 'U1 update'
        u2.name = 'U2 update'

        u1.save!
        u2.save!

        u1.neo_find_by_id.name.should == 'U1'
        u2.neo_find_by_id.name.should == 'U2'
      end

      res.length.should == 2

      u1.neo_find_by_id.name.should == 'U1 update'
      u2.neo_find_by_id.name.should == 'U2 update'
    end
  end

  context 'relationships' do
    let(:user) { User.create(name: 'Elad Ossadon', slug: 'elado') }
    let(:movie) { Movie.create(name: 'Memento', slug: 'memento-1999', year: 1999) }

    it 'should not execute until batch is done' do
      res = Neoid.batch do |batch|
        user.like! movie

        user.likes.last.neo_find_by_id.should be_nil
      end

      res.length.should == 1

      user.likes.last.neo_find_by_id.should_not be_nil
    end

    it 'should not execute until batch is done' do
      # then destroy the nodes, allow the relationship do that in the batch
      user.neo_destroy
      movie.neo_destroy

      res = Neoid.batch do |batch|
        user.like! movie

        user.likes.last.neo_find_by_id.should be_nil
      end

      res.length.should == 3

      user.likes.last.neo_find_by_id.should_not be_nil
    end
  end
end
