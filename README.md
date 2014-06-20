# Neoid

[![Gem Version](https://badge.fury.io/rb/neoid.svg)](http://badge.fury.io/rb/neoid)
[![Code Climate](https://codeclimate.com/github/neoid-gem/neoid.png)](https://codeclimate.com/github/neoid-gem/neoid)
[![Build Status](https://secure.travis-ci.org/neoid-gem/neoid.png)](http://travis-ci.org/neoid-gem/neoid)

__This gem is not stable. There are currently no stable versions. We're working on fixing this right now. Apologies.__

Make your ActiveRecords stored and searchable on Neo4j graph database, in order to make fast graph queries that MySQL would crawl while doing them. Originally by [@elado](http://twitter.com/elado).

Neoid is to Neo4j as Sunspot is to Solr. You get the benefits of Neo4j's speed while keeping your schema on your RDBMS.

Neoid does not require JRuby. It's based on the [Neography](https://github.com/maxdemarzi/neography) gem which uses Neo4j's REST API.

Neoid offers querying Neo4j for IDs of objects and then fetch them from your RDBMS, or storing all desired data on Neo4j.

__Important: If you are hosting your application on Heroku with Neoid, [GrapheneDB](http://www.graphenedb.com/) does support Gremlin code; their add-on is [located here](https://addons.heroku.com/graphenedb). Also be reminded that the Gremlin code is actively being refactored into Cypher.__

## Changelog

[See Changelog](https://github.com/elado/neoid/blob/master/CHANGELOG.md). Including some breaking changes (and solutions) from previos versions.


## Installation

Add to your Gemfile and run the `bundle` command to install it.

```ruby
gem 'neoid'
```

**Requires Ruby 1.9.3 or later and Neo4j 1.9.8.**

### Installing Neo4j 1.9.8 for your project

We're currently working to bump to 2.1.x land, but for now, you have to use 1.9.8. To get started, install neo4j locally in your project with:

```bash
gem install neo4j-core --pre
rake neo4j:install[community,1.9.8]
rake neo4j:start
```

## Usage

### Rails app configuration:

Initializer neography and neoid in an initializer that is prefixed with `01_`, such as `config/initializers/01_neo4j.rb`:

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

Neoid.configure do |c|
  # should Neoid create sub-reference from the ref node (id#0) to every node-model? default: true
  c.enable_subrefs = true
end
```

### ActiveRecord configuration

#### Nodes

For nodes, first include the `Neoid::Node` module in your model:


```ruby
class User < ActiveRecord::Base
  include Neoid::Node
end
```

This will help to create/update/destroy a corresponding node on Neo4j when changed are made a User model.

Then, you can customize what fields will be saved on the node in Neo4j, inside `neoidable` configuration, using `field`. You can also pass blocks to save content that's not a real column:

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
```

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

Neoid adds the methods `neo_node` and `neo_relationships` to instances of nodes and relationships, respectively.

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

#### Disabling auto saving to Neo4j:

If you'd like to save nodes manually rather than after_save, use `auto_index: false`:

```ruby
class User < ActiveRecord::Base
  include Neoid::Node
  
  neoidable auto_index: false do |c|
  end
end

user = User.create!(name: "Elad") # no node is created in Neo4j!

user.neo_save # now there is!
```

## Querying

You can query with all [Neography](https://github.com/maxdemarzi/neography)'s API: `traverse`, `execute_query` for Cypher, and `execute_script` for Gremlin.

### Basics:

#### Finding a node by ID

Nodes and relationships are auto indexed in the `node_auto_index` and `relationship_auto_index` indexes, where the key is `Neoid::UNIQUE_ID_KEY` (which is 'neoid_unique_id') and the value is a combination of the class name and model id, `Movie:43`, this value is accessible with `model.neo_unique_id`. So use the constant and this method, never rely on assebling those values on your own because they might change in the future.

That means, you can query like this:

```ruby
Neoid.db.get_node_auto_index(Neoid::UNIQUE_ID_KEY, user.neo_unique_id)
# => returns a Neography hash

Neoid::Node.from_hash(Neoid.db.get_node_auto_index(Neoid::UNIQUE_ID_KEY, user.neo_unique_id))
# => returns a Neography::Node
```

#### Finding all nodes of type

If Subreferences are enabled, you can get the subref node and then get all attached nodes:

```ruby
Neoid.ref_node.outgoing('users_subref').first.outgoing('users').to_a
# => this, according to Neography, returns an array of Neography::Node so no conversion is needed
```

### Gremlin Example:

These examples query Neo4j using Gremlin for IDs of objects, and then fetches them from ActiveRecord with an `in` query.

Of course, you can store using the `neoidable do |c| c.field ... end` all the data you need in Neo4j and avoid querying ActiveRecord.


**Most liked movies**

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

*Side note: the resulted movies won't be sorted by like count because the RDBMS won't necessarily do it as we passed a list of IDs. You can sort it yourself with array manipulation, since you have the ids.*


**Movies of user friends that the user doesn't have**

Let's assume we have another `Friendship` model which is a relationship with start/end nodes of `user` and type of `friends`,

```ruby
user = User.find(1)

gremlin_query = <<-GREMLIN
  u = g.idx('node_auto_index').get(unique_id_key, user_unique_id).next()
  movies = []

  u
    .out('likes').aggregate(movies).back(2)
    .out('friends').out('likes')
    .dedup
    .except(movies).collect{it.ar_id}
GREMLIN

movie_ids = Neoid.db.execute_script(gremlin_query, unique_id_key: Neoid::UNIQUE_ID_KEY, user_unique_id: user.neo_unique_id)

Movie.where(id: movie_ids)
```

## Full Text Search

### Index for Full-Text Search

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

### Querying a Full-Text Search index

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

Full text search with Neoid is very limited and is likely not to develop more than this basic functionality. I strongly recommend using gems like Sunspot over Solr.

## Batches

Neoid has a batch ability, that is good for mass updateing/inserting of nodes/relationships. It sends batched requests to Neography, and takes care of type conversion (neography batch returns hashes and other primitive types) and "after" actions (via promises).

A few examples, easy to complex:

```ruby
Neoid.batch(batch_size: 100) do
  User.all.each(&:neo_save)
end
```
With `then`:

```ruby
User.first.name # => "Elad"

Neoid.batch(batch_size: 100) do
  User.all.each(&:neo_save)
end.then do |results|
  # results is an array of the script results from neo4j REST.

  results[0].name # => "Elad"
end
```

*Nodes and relationships in the results are automatically converted to Neography::Node and Neography::Relationship, respectively.*

With individual `then` as well as `then` for the entire batch:

```ruby
Neoid.batch(batch_size: 30) do |batch|
  (1..90).each do |i|
    (batch << [:create_node, { name: "Hello #{i}" }]).then { |result| puts result.name }
  end
end.then do |results|
  puts results.collect(&:name)
end
```

When in a batch, `neo_save` adds gremlin scripts to a batch, instead of running them immediately. The batch flushes whenever the `batch_size` option is met.
So even if you have 20000 users, Neoid will insert/update in smaller batches. Default `batch_size` is 200.


## Inserting records of existing app

If you have an existing database and just want to integrate Neoid, configure the `neoidable`s and run in a rake task or console.

Use batches! It's free, and much faster. Also, you should use `includes` to incude the relationship edges on relationship entities, so it doesn't query the DB on each relationship.

```ruby
Neoid.batch do
  [ Like.includes(:user).includes(:movie), OtherRelationshipModel.includes(:from_model).includes(:to_model) ].each { |model| model.all.each(&:neo_save) }

  NodeModel.all.each(&:neo_save)
end
```

This will loop through all of your relationship records and generate the two edge nodes along with a relationship (eager loading for better performance).
The second line is for nodes without relationships.

For large data sets use pagination.
Better interface for that in the future.


## Behind The Scenes

Whenever the `neo_node` on nodes or `neo_relationship` on relationships is called, Neoid checks if there's a corresponding node/relationship in Neo4j (with the auto indexes). If not, it does the following:

### For Nodes:

1. Ensures there's a sub reference node (read [here](http://docs.neo4j.org/chunked/stable/tutorials-java-embedded-index.html) about sub references), if that option is on.
2. Creates a node based on the ActiveRecord, with the `id` attribute and all other attributes from `neoidable`'s field list
3. Creates a relationship between the sub reference node and the newly created node
4. Auto indexes a node in the auto index, for fast lookup in the future

Then, when it needs to find it again, it just seeks the auto index with that ActiveRecord id.

### For Relationships:

Like Nodes, it uses an auto index, to look up a relationship by ActiveRecord id

1. With the options passed in the `neoidable`, it fetches the `start_node` and `end_node`
2. Then, it calls `neo_node` on both, in order to create the Neo4j nodes if they're not created yet, and creates the relationship with the type from the options.
3. Adds the relationship to the relationship index.

## Testing

In order to test your app or this gem, you need a running Neo4j database, dedicated to tests.

I use port 7574 for testing.

To run another database locally (read
[here](http://docs.neo4j.org/chunked/stable/ha-setup-tutorial.html#ha-local-cluster) too):

Copy the entire Neo4j database folder to a different location,

**or**

symlink `bin`, `lib`, `plugins`, `system`, copy `conf` to a single folder, and create an empty `data` folder.

Then, edit `conf/neo4j-server.properties` and set the port (`org.neo4j.server.webserver.port`) from 7474 to 7574 and run the server with `bin/neo4j start`

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

Run the Neo4j DB on port 7474, and run `rake` from the gem folder.

## Contributing

Please create a [new issue](https://github.com/elado/neoid/issues) if you run into any bugs. Contribute patches via pull requests. Write tests and make sure all tests pass.

## TO DO

[TO DO](https://github.com/elado/neoid/blob/master/TODO.md)

---

Developed by [@elado](http://twitter.com/elado) and [@BenMorganIO](http://twitter.com/BenMorganIO)
