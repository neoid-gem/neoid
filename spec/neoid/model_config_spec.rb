require 'spec_helper'
require 'fileutils'

describe Neoid::ModelConfig do
  context 'config on a model' do
    it 'should store search fields' do
      Article.neoid_config.search_options.should_not be_nil
      Article.neoid_config.search_options.index_fields.keys.should =~ [ :title, :body, :year ]
    end

    it 'should store stored fields' do
      Article.neoid_config.stored_fields.should_not be_nil
      Article.neoid_config.stored_fields.keys.should =~ [ :title, :year, :title_length ]
      Article.neoid_config.stored_fields[:title_length].should be_a(Proc)
    end

    it 'should store stored fields based on blocks' do
      article = Article.create! title: 'Hello', year: 2012

      article.neo_node.title_length.should == article.title.length
    end
  end
end
