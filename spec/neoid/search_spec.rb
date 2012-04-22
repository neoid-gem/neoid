require 'spec_helper'
require 'fileutils'

describe Neoid::ModelAdditions do
  context "search" do
    let(:index_name) { "articles_search_index_#{Time.now.to_f.to_s.gsub('.', '')}" }

    before(:each) do
      Article.stub!(:neo_search_index_name).and_return(index_name)
    end

    it "should index and find node in fulltext" do
      Neoid.db.create_node_index(index_name, "fulltext", "lucene")

      n = Neography::Node.create(:name => "test hello world", :year => 2012)
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
      article = Article.create!(:title => "Hello world", :body => "Lorem ipsum dolor sit amet", :year => 2012)

      [
        "title:Hello",
        "year:2012",
        "title:Hello AND year:2012"
      ].each { |q|
        results = Neoid.db.find_node_index(index_name, q)
        results.should_not be_nil
        results.length.should == 1
        Neoid.db.send(:get_id, results).should == article.neo_node.neo_id
      }
    end

    context "search session" do
      it "should return a search session" do
        Article.search("hello").should be_a(Neoid::SearchSession)
      end

      it "should find hits" do
        article = Article.create!(:title => "Hello world", :body => "Lorem ipsum dolor sit amet", :year => 2012)

        Article.search("hello").hits.should == [ article.neo_node ]
      end

      it "should find results" do
        article = Article.create!(:title => "Hello world", :body => "Lorem ipsum dolor sit amet", :year => 2012)

        Article.search("Hello").results.should == [ article ]
      end
    end
  end
end
