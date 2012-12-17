# Neoid

[![Build Status](https://secure.travis-ci.org/elado/neoid.png)](http://travis-ci.org/elado/neoid)



Make your ActiveRecords stored and searchable on Neo4j graph database, in order to make fast graph queries that MySQL would crawl while doing them.

Neoid to Neo4j is like Sunspot to Solr. You get the benefits of Neo4j speed while keeping your schema on your plain old RDBMS.

Neoid doesn't require JRuby. It's based on the great [Neography](https://github.com/maxdemarzi/neography) gem which uses Neo4j's REST API.

Neoid offers querying Neo4j for IDs of objects and then fetch them from your RDBMS, or storing all desired data on Neo4j.



## Installation

Add to your Gemfile and run the `bundle` command to install it.

```ruby
gem 'neoid', git: 'git://github.com/elado/neoid.git'
```

**Requires Ruby 1.9.2 or later.**

## Usage

### Rails app configuration:

In an initializer, such as `config/initializers/01_neo4j.rb`:

```ruby
ENV["NEO4J_URL"] ||= "http://localhost:7474"

uri = URI.parse(ENV["NEO4J_URL"])

$neo = Neography::Rest.new(uri.to_s)

Neography.configure do |c|
  c.server = uri.host
  c.port = uri.port

  if uri.user && uri.password
    c.authentication = 'basic'
    c.username = uri.user
    c.password = uri.password
  end
end

Neoid.db = $neo
```

`01_` in the file name is in order to get this file loaded first, before the models (initializers are loaded alphabetically).

If you have a better idea (I bet you do!) please let me know.


### ActiveRecord configuration

#### Nodes

For nodes, first include the `Neoid::Node` module in your model:


```ruby
class User < ActiveRecord::Base
  include Neoid::Node
end
```

This will help to create a corresponding node on Neo4j when a user is created, delete it when a user is destroyed, and update it if needed.

Then, you can customize what fields will be saved on the node in Neo4j, inside neoidable configuration:

```ruby
class User < ActiveRecord::Base
  include Neoid::Node
  
  neoidable do |c|
    c.field :slug
    c.field :display_name
    c.field :display_name_length do
      self.display_name.length
    end
  end
end
```ruby


#### Relationships

Let's assume that a `User` can `Like` `Movie`s:


```ruby
# user.rb

class User < ActiveRecord::Base
  include Neoid::Node

  has_many :likes
  has_many :movies, through: :likes

  neoidable do |c|
    c.field :slug
    c.field :display_name
  end
end


# movie.rb

class Movie < ActiveRecord::Base
  include Neoid::Node

  has_many :likes
  has_many :users, through: :likes

  neoidable do |c|
    c.field :slug
    c.field :name
  end
end


# like.rb

class Like < ActiveRecord::Base
  belongs_to :user
  belongs_to :movie
end
```


Now let's make the `Like` model a Neoid, by including the `Neoid::Relationship` module, and define the relationship (start & end nodes and relationship type) options with `neoidable` config and `relationship` method:


```ruby
class Like < ActiveRecord::Base
  belongs_to :user
  belongs_to :movie

  include Neoid::Relationship

  neoidable do |c|
    c.relationship start_node: :user, end_node: :movie, type: :likes
  end
end
```

Neoid adds `neo_node` and `neo_relationships` to nodes and relationships, respectively.

So you could do:

```ruby
user = User.create!(display_name: "elado")
user.movies << Movie.create("Memento")
user.movies << Movie.create("Inception")

user.neo_node                # => #<Neography::Node…>
user.neo_node.display_name   # => "elado"

rel = user.likes.first.neo_relationship
rel.start_node  # user.neo_node
rel.end_node    # user.movies.first.neo_node
rel.rel_type    # 'likes'
```

## Index for Full-Text Search

Using `search` block inside a `neoidable` block, you can store certain fields.

```ruby
# movie.rb

class Movie < ActiveRecord::Base
  include Neoid::Node

  neoidable do |c|
    c.field :slug
    c.field :name

    c.search do |s|
      # full-text index fields
      s.fulltext :name
      s.fulltext :description

      # just index for exact matches
      s.index :year
    end
  end
end
```

Records will be automatically indexed when inserted or updated.

## Querying

You can query with all [Neography](https://github.com/maxdemarzi/neography)'s API: `traverse`, `execute_query` for Cypher, and `execute_script` for Gremlin.

### Gremlin Example:

These examples query Neo4j using Gremlin for IDs of objects, and then fetches them from ActiveRecord with an `in` query.

Of course, you can store using the `neoidable do |c| c.field ... end` all the data you need in Neo4j and avoid querying ActiveRecord.


**Most popular categories**

```ruby
gremlin_query = <<-GREMLIN
  m = [:]

  g.v(0)
    .out('movies_subref').out
      .inE('likes')
      .inV
      .groupCount(m).iterate()

  m.sort{-it.value}.collect{it.key.ar_id}
GREMLIN

movie_ids = Neoid.db.execute_script(gremlin_query)

Movie.where(id: movie_ids)
```

Assuming we have another `Friendship` model which is a relationship with start/end nodes of `user` and type of `friends`,

**Movies of user friends that the user doesn't have**

```ruby
user = User.find(1)

gremlin_query = <<-GREMLIN
  u = g.idx('users_index')[[ar_id:user_id]].next()
  movies = []

  u
    .out('likes').aggregate(movies).back(2)
    .out('friends').out('likes')
    .dedup
    .except(movies).collect{it.ar_id}
GREMLIN

movie_ids = Neoid.db.execute_script(gremlin_query, user_id: user.id)

Movie.where(id: movie_ids)
```

`.next()` is in order to get a vertex object which we can actually query on.


### Full Text Search

```ruby
# will match all movies with full-text match for name/description. returns ActiveRecord instanced
Movie.neo_search("*hello*").results

# same as above but returns hashes with the values that were indexed on Neo4j
Movie.search("*hello*").hits

# search in multiple types
Neoid.neo_search([Movie, User], "hello")

# search with exact matches (pass a hash of field/value)
Movie.neo_search(year: 2013).results
```

## Inserting records of existing app

If you have an existing database and just want to integrate Neoid, configure the `neoidable`s and run in a rake task or console

```ruby
Model.all.each(&:neo_update)
```

On large datasets use pagination. Better interface for that in the future.


## Behind The Scenes

Whenever the `neo_node` on nodes or `neo_relationship` on relationships is called, Neoid checks if there's a corresponding node/relationship in Neo4j. If not, it does the following:

### For Nodes:

1. Ensures there's a sub reference node (read [here](http://docs.neo4j.org/chunked/stable/tutorials-java-embedded-index.html) about sub reference nodes)
2. Creates a node based on the ActiveRecord, with the `id` attribute and all other attributes from `neoidable`'s field list
3. Creates a relationship between the sub reference node and the newly created node
4. Adds the ActiveRecord `id` to a node index, pointing to the Neo4j node id, for fast lookup in the future

Then, when it needs to find it again, it just seeks the node index with that ActiveRecord id for its neo node id.

### For Relationships:

Like Nodes, it uses an index (relationship index) to look up a relationship by ActiveRecord id

1. With the options passed in the `neoidable`, it fetches the `start_node` and `end_node`
2. Then, it calls `neo_node` on both, in order to create the Neo4j nodes if they're not created yet, and creates the relationship with the type from the options.
3. Add the relationship to the relationship index.

## Testing

In order to test your app or this gem, you need a running Neo4j database, dedicated to tests.

I use port 7574 for this. To run another database locally:

Copy the entire Neo4j database folder to a different location,

**or**

symlink `bin`, `lib`, `plugins`, `system`, copy `conf` to a single folder, and create an empty `data` folder.

Then, edit `conf/neo4j-server.properties` and set the port (`org.neo4j.server.webserver.port`) from 7474 to 7574 and run the server with `bin/neo4j start`

**You also want clean DB addon:**

Download, install and configure [neo4j-clean-remote-db-addon](https://github.com/jexp/neo4j-clean-remote-db-addon). For the test database, leave the default `secret-key` key.

## Testing Your App with Neoid (RSpec)

In `environments/test.rb`, add:

```ruby
ENV["NEO4J_URL"] = 'http://localhost:7574'
```

In your `spec_helper.rb`, add the following configurations:

```ruby
config.before :all do
  Neoid.clean_db(:yes_i_am_sure)
end

config.before :each do
  Neoid.reset_cached_variables
end
```

## Testing This Gem

Just run `rake` from the gem folder.

## Contributing

Please create a [new issue](https://github.com/elado/neoid/issues) if you run into any bugs. Contribute patches via pull requests. Write tests and make sure all tests pass.



## To Do

[To Do](https://github.com/elado/neoid/blob/master/TODO.md)


---

Developed by [@elado](http://twitter.com/elado)