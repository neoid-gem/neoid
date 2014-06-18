require 'spec_helper'

describe Neoid::ModelAdditions do
  context 'search' do
    let(:index_name) { "articles_search_index_#{Time.now.to_f.to_s.gsub('.', '')}" }
    
    it 'should index and find node in fulltext' do
      Neoid.db.create_node_index(index_name, 'fulltext', 'lucene')
      
      n = Neography::Node.create(name: 'test hello world', year: 2012)
      Neoid.db.add_node_to_index(index_name, 'name', n.name, n)
      Neoid.db.add_node_to_index(index_name, 'year', n.year, n)
      
      [
        'name:test',
        'year:2012',
        'name:test AND year:2012'
      ].each { |q|
        results = Neoid.db.find_node_index(index_name, q)
        results.length.should == 1
        Neoid.db.send(:get_id, results).should == n.neo_id
      }
    end
    
    it 'should index item on save' do
      r = rand(1000000)
      article = Article.create!(title: "Hello world #{r}", body: 'Lorem ipsum dolor sit amet', year: r)

      [
        "title:#{r}",
        "year:#{r}",
        "title:#{r} AND year:#{r}"
      ].each do |q|
        results = Neoid.db.find_node_index(Neoid::DEFAULT_FULLTEXT_SEARCH_INDEX_NAME, q)

        results.should_not be_nil
        results.length.should == 1
        Neoid.db.send(:get_id, results).should == article.neo_node.neo_id
      end
    end

    context 'search session' do
      it 'should return a search session' do
        Article.neo_search('hello').should be_a(Neoid::SearchSession)
      end

      it 'should find hits' do
        article = Article.create!(title: 'Hello world', body: 'Lorem ipsum dolor sit amet', year: 2012)
        
        Article.neo_search('hello').hits.should == [ article.neo_node ]
      end
      
      it 'should find results with a search string' do
        article = Article.create!(title: 'Hello world', body: 'Lorem ipsum dolor sit amet', year: 2012)

        Article.neo_search('hello').results.should == [ article ]
      end
      
      it 'should find results with a hash' do
        articles = [
          Article.create!(title: 'How to draw manga', body: 'Lorem ipsum dolor sit amet', year: 2012),
          Article.create!(title: 'Manga x', body: 'Lorem ipsum dolor sit amet', year: 2013)
        ]


        Article.neo_search(year: 2012).results.should == [ articles[0] ]
      end
    end

    context 'search in multiple types' do
      before :each do
        @articles = [
          Article.create!(title: 'How to draw manga', body: 'Lorem ipsum dolor sit amet', year: 2012),
          Article.create!(title: 'Manga x', body: 'Lorem ipsum dolor sit amet', year: 2012)
        ]

        @movies = [
          Movie.create!(name: 'Anime is not Manga', slug: 'anime')
        ]
      end

      it 'should search in multiple types' do
        Neoid.search([Article, Movie], 'manga').results.should =~ @articles + @movies
      end

      it 'should search in single type when specified' do
        Neoid.search([Article], 'manga').results.should =~ @articles
      end
    end

    context 'search matching types' do
      before :each do
        @articles = [
          Article.create!(title: 'Comics: How to draw manga', body: 'Lorem ipsum dolor sit amet', year: 2012),
          Article.create!(title: 'Manga x', body: 'Lorem ipsum dolor sit amet', year: 2012),
          Article.create!(title: 'hidden secrets of comics masters', body: 'Lorem ipsum dolor sit amet', year: 2012),
          Article.create!(title: 'hidden secrets of manga comics artists', body: 'Lorem ipsum dolor sit amet', year: 2012)
        ]
      end

      it 'should return search results only matches with AND' do
        Neoid.search([Article],'manga comics').results.size.should eq(1)

        Neoid.search([Article],'manga comics', match_type: 'AND').results.size.should eq(1)
      end

      it 'should return search results all results with OR' do
        Neoid.search([Article],'manga comics', match_type: 'OR').results.size.should eq(4)
      end

      it 'should fail with wrong match_type' do
        expect {Neoid.search([Article],'manga comics', match_type: 'MAYBE')}.to raise_error('Invalid match_type option. Valid values are AND,OR')
      end
    end
  end
end
