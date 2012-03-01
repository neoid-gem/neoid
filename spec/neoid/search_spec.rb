require 'spec_helper'
require 'fileutils'

describe Neoid::ModelAdditions do
  context "search" do
    class Article < SuperModel::Base
      include ActiveModel::Validations::Callbacks
      include Neoid::Node
      neoidable do |c|
        c.search do |s|
          s.index :name
          s.index :body
          s.index :year
        end
        
        c.field :name
        c.field :year
      end
    end
    
    let(:unique) { Time.now.to_f.to_s.gsub('.', '') }
    
    it "should index and find node in fulltext" do
      index_name = "test_index_#{unique}"
      Neoid.db.create_node_index(index_name, "fulltext", "lucene")
      
      n = Neography::Node.create(name: "test hello world", year: 2012)
      Neoid.db.add_node_to_index(index_name, "name", n.name, n)
      Neoid.db.add_node_to_index(index_name, "year", n.year, n)
      
      [
        "name:test",
        "year:2012",
        "name:test AND year:2012"
      ].each { |q|
        results = Neoid.db.find_node_index(index_name, q)
        results.length.should == 1
        Neoid.db.send(:get_id, results).should == n.neo_id
      }
    end
    
    it "should index item on save" do
      index_name = "articles_search_index_#{unique}"
      
      Article.stub!(:neo_search_index_name).and_return(index_name)
      
      article = Article.create!(name: "Hello world", body: "Lorem ipsum dolor sit amet", year: 2012)
      
      [
        "name:Hello",
        "year:2012",
        "name:Hello AND year:2012"
      ].each { |q|
        results = Neoid.db.find_node_index(index_name, q)
        results.should_not be_nil
        results.length.should == 1
        Neoid.db.send(:get_id, results).should == article.neo_node.neo_id
      }
    end
  end
end
