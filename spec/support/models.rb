class User < SuperModel::Base
  include ActiveModel::Validations::Callbacks
  
  has_many :likes
  has_many :movies, through: :likes
  
  # _test_movies is here because SuperModel doesn't handle has_many queries
  # it simulates the database. see comments in each method to see a regular AR implementation
  def _test_movies
    @_test_movies ||= []
  end
  
  def likes?(movie)
    # likes.where(movie_id: movie.id).exists?
    _test_movies.any? { |it| it.movie_id == movie.id }
  end
  
  def like!(movie)
    # movies << movie unless likes?(movie)
    _test_movies << Like.create(user_id: self.id, movie_id: movie.id) unless likes?(movie)
  end
  
  def unlike!(movie)
    # likes.where(movie_id: movie.id, user_id: self.id).destroy_all
    _test_movies.delete_if { |it| it.destroy if it.movie_id == movie.id }
  end
  
  include Neoid::Node
  
  neoidable do |c|
    c.field :name
    c.field :slug
  end
end

class Movie < SuperModel::Base
  include ActiveModel::Validations::Callbacks
  
  has_many :likes
  has_many :users, through: :likes
  
  include Neoid::Node
  
  neoidable do |c|
    c.field :name
    c.field :slug
    c.field :year
  end
end

class Like < SuperModel::Base
  include ActiveModel::Validations::Callbacks
  
  belongs_to :user
  belongs_to :movie
  
  include Neoid::Relationship
  
  neoidable do |c|
    c.relationship start_node: :user, end_node: :movie, type: :likes
    c.field :rate
  end
end
