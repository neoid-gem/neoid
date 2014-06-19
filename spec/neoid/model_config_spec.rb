require 'spec_helper'
require 'fileutils'

describe Neoid::ModelConfig do
  context 'config on a model' do
    it 'stores stored_fields based on blocks' do
      article = Article.create!(title: 'Hello', year: 2012)
      expect(article.neo_node.title_length).to eq(article.title.length)
    end

    describe '.search_options' do
      subject(:search_options) { Article.neoid_config.search_options }

      it { should_not be_nil }
      its('index_fields.keys') { should match_array([:title, :body, :year]) }
    end

    describe '.stored_fields' do
      subject(:stored_fields) { Article.neoid_config.stored_fields }
      it { should_not be_nil }
      its(:keys) { should match_array([:title, :year, :title_length]) }
      its([:title_length]) { should be_a(Proc) }
    end
  end
end
