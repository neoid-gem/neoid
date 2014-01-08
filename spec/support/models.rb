class User < ActiveRecord::Base
  include ActiveModel::Validations::Callbacks
  
  has_many :likes
  has_many :movies, through: :likes

  has_many :user_follows
  
  def likes?(movie)
    likes.where(movie_id: movie.id).exists?
  end
  
  def like!(movie)
    movies << movie unless likes?(movie)
    likes.where(movie_id: movie.id).first
  end
  
  def unlike!(movie)
    likes.where(movie_id: movie.id, user_id: self.id).destroy_all
  end
  
  include Neoid::Node
  neo_init :main

  neoidable do |c|
    c.field :name
    c.field :slug
  end
end

class Movie < ActiveRecord::Base
  include ActiveModel::Validations::Callbacks
  
  has_many :likes
  has_many :users, through: :likes
  
  include Neoid::Node
  neo_init
  
  neoidable do |c|
    c.field :name
    c.field :slug
    c.field :year

    c.search do |s|
      s.fulltext :name

      s.index :name
      s.index :slug
      s.index :year
    end
  end
end

class UserFollow < ActiveRecord::Base
  include ActiveModel::Validations::Callbacks

  belongs_to :user
  belongs_to :item, polymorphic: true
  
  include Neoid::Relationship
  neo_init
  
  neoidable do |c|
    c.relationship start_node: :user, end_node: :item, type: :follows
  end
end

class Like < ActiveRecord::Base
  include ActiveModel::Validations::Callbacks
  
  belongs_to :user
  belongs_to :movie
  
  include Neoid::Relationship
  neo_init
  
  neoidable do |c|
    c.relationship start_node: :user, end_node: :movie, type: :likes
    c.field :rate
  end
end

class Article < ActiveRecord::Base
  include ActiveModel::Validations::Callbacks
  include Neoid::Node
  neo_init

  neoidable do |c|
    c.field :title
    c.field :year
    c.field :title_length do
      self.title ? self.title.length : 0
    end

    c.search do |s|
      s.fulltext :title

      s.index :title
      s.index :body
      s.index :year
    end
  end
end

class NoAutoIndexNode < ActiveRecord::Base
  include ActiveModel::Validations::Callbacks
  include Neoid::Node
  neo_init

  neoidable auto_index: false do |c|
    c.field :name
  end
end
