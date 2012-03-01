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
    
    it "should index and find node in fulltext" do
      Neoid.db.create_node_index("x_idx", "fulltext", "lucene")
      
      n = Neography::Node.create(name: "test hello world", year: 2012)
      Neoid.db.add_node_to_index("x_idx", "name", n.name, n)
      Neoid.db.add_node_to_index("x_idx", "year", n.year, n)
      
      [
        "name:test",
        "year:2012",
        "name:test AND year:2012"
      ].each { |q|
        results = Neoid.db.find_node_index("x_idx", q)
        results.length.should == 1
        Neoid.db.send(:get_id, results).should == n.neo_id
      }
    end
    
    it "should index item on save" do
      article = Article.create!(name: "Hello world", body: "Lorem ipsum dolor sit amet", year: 2012)
      
      # # Neoid.db.should_receive(:add_node_to_index).with("articles_search_index", "name", article.name)
      # # Neoid.db.should_receive(:add_node_to_index).with("articles_search_index", "name", article.body)
      
      [
        "name:test",
        "year:2012",
        "name:test AND year:2012"
      ].each { |q|
        results = Neoid.db.find_node_index("articles_search_index", "name:hello")
        results.length.should == 1
        Neoid.db.send(:get_id, results).should == article.neo_node.neo_id
      }
    end
  end
end
