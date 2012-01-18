# DRAFT ONLY - GEM IS NOT HOSTED YET.

# Neoid

Make your ActiveRecords stored and searchable on Neo4j graph database, in order to make fast graph queries that MySQL would crawl while doing them.

Neoid to Neo4j is like Sunspot to Solr. You get the benefits of Neo4j speed while keeping your schema on your plain old RDBMS.

Neoid doesn't require JRuby. It's based on the great [Neography](https://github.com/maxdemarzi/neography) gem which uses Neo4j's REST API.

Neoid offers querying Neo4j for IDs of objects and then fetch them from your RDBMS, or storing all desired data on Neo4j.



## Installation

Add to your Gemfile and run the `bundle` command to install it.

	gem 'neoid'


**Requires Ruby 1.9.2 or later.**

## Usage

### First app configuration:

In an initializer, such as `config/initializers/01_neo4j.rb`:

	ENV["NEO4J_URL"] ||= "http://localhost:7474"

	uri = URI.parse(ENV["NEO4J_URL"])

    $neo = Neography::Rest.new(neo4j_uri.to_s)

    Neography::Config.tap do |c|
      c.server = uri.host
      c.port = uri.port

      if uri.user && uri.password
        c.authentication = 'basic'
        c.username = uri.user
        c.password = uri.password
      end
    end

    Neoid.db = $neo


`01_` in the file name is in order to get this file loaded first, before the models (files are loaded alphabetically).

If you have a better idea (I bet you do!) please let me know.


### ActiveRecord configuration

#### Nodes

For nodes, first include the `Neoid::Node` module in your model:


	class User < ActiveRecord::Base
      include Neoid::Node
	end


This will help to create a corresponding node on Neo4j when a user is created, delete it when a user is destroyed, and update it if needed.

Then, you can customize what fields will be saved on the node in Neo4j, by implementing `to_neo` method:


	class User < ActiveRecord::Base
      include Neoid::Node
    
	  def to_neo
        {
          slug: slug,
          display_name: display_name
	    }
      end
	end

You can use `neo_properties_to_hash`, a helper method to make  things shorter:


	def to_neo
	  neo_properties_to_hash(%w(slug display_name))
	end


#### Relationships

Let's assume that a `User` can `Like` `Movie`s:


	# user.rb

	class User < ActiveRecord::Base
      include Neoid::Node
    
	  has_many :likes
      has_many :movies, through: :likes
    
	  def to_neo
        neo_properties_to_hash(%w(slug display_name))
	  end
	end


	# movie.rb

	class Movie < ActiveRecord::Base
      include Neoid::Node
    
	  has_many :likes
      has_many :users, through: :likes
    
	  def to_neo
        neo_properties_to_hash(%w(slug name))
	  end
	end


	# like.rb

	class Like < ActiveRecord::Base
	  belongs_to :user
      belongs_to :movie
	end



Now let's make the `Like` model a Neoid, by including the `Neoid::Relationship` module, and define the relationship (start & end nodes and relationship type) options with `neoidable` method:


	class Like < ActiveRecord::Base
	  belongs_to :user
	  belongs_to :movie

	  include Neoid::Relationship
	  neoidable start_node: :user, end_node: :movie, type: :likes
	end


Neoid adds `neo_node` and `neo_relationships` to nodes and relationships, respectively.

So you could do:

	user = User.create!(display_name: "elado")
	user.movies << Movie.create("Memento")
	user.movies << Movie.create("Inception")

	user.neo_node                # => #<Neography::Node…>
	user.neo_node.display_name   # => "elado"

	rel = user.likes.first.neo_relationship
	rel.start_node  # user.neo_node
	rel.end_node    # user.movies.first.neo_node
	rel.rel_type    # 'likes'


## Querying

You can query with all [Neography](https://github.com/maxdemarzi/neography)'s API: `traverse`, `execute_query` for Cypher, and `execute_script` for Gremlin.

### Gremlin Example:

These examples query Neo4j using Gremlin for IDs of objects, and then fetches them from ActiveRecord with an `in` query.

Of course, you can store using the `to_neo` all the data you need in Neo4j and avoid querying ActiveRecord.


**Most popular categories**

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


Assuming we have another `Friendship` model which is a relationship with start/end nodes of `user` and type of `friends`,

**Movies of user friends that the user doesn't have**

	user = User.find(1)

	gremlin_query = <<-GREMLIN
	  u = g.idx('users_index')[[ar_id:'#{user.id}']][0].toList()[0]
	  movies = []

	  u
		.out('likes').aggregate(movies).back(2)
	    .out('friends').out('likes')
		.dedup
		.except(movies).collect{it.ar_id}
	GREMLIN

	movie_ids = Neoid.db.execute_script(gremlin_query)

	Movie.where(id: movie_ids)


`[0].toList()[0]` is in order to get a pipeline object which we can actually query on.


## Behind The Scenes

Whenever the `neo_node` on nodes or `neo_relationship` on relationships is called, Neoid checks if there's a corresponding node/relationship in Neo4j. If not, it does the following:

### For Nodes:

1. Ensures there's a sub reference node (read [here](http://docs.neo4j.org/chunked/stable/tutorials-java-embedded-index.html) about sub reference nodes)
2. Creates a node based on the ActiveRecord, with the `id` attribute and all other attributes from `to_neo`
3. Creates a relationship between the sub reference node and the newly created node
4. Adds the ActiveRecord `id` to a node index, pointing to the Neo4j node id, for fast lookup in the future

Then, when it needs to find it again, it just seeks the node index with that ActiveRecord id for its neo node id.

### For Relationships:

Like Nodes, it uses an index (relationship index) to look up a relationship by ActiveRecord id

1. With the options passed in the `neoidable`, it fetches the `start_node` and `end_node`
2. Then, it calls `neo_node` on both, in order to create the Neo4j nodes if they're not created yet, and creates the relationship with the type from the options.
3. Add the relationship to the relationship index.

## Testing

Neoid tests run on a regular Neo4j database, on port 7574. You probably want to have it running on a different instance than your development one.

In order to do that:

Copy the Neo4j folder to a different location,

**or**

symlink `bin`, `lib`, `plugins`, `system`, copy `conf` and create an empty `data` folder.

Then, edit `conf/neo4j-server.properties` and set the port (`org.neo4j.server.webserver.port`) from 7474 to 7574 and run the server with `bin/neo4j start`


Download, install and configure [neo4j-clean-remote-db-addon](https://github.com/jexp/neo4j-clean-remote-db-addon). For the test database, leave the default `secret-key` key.


## Contributing

Please create a [new issue](https://github.com/elado/neoid/issues) if you run into any bugs. Contribute patches via pull requests. Write tests and make sure all tests pass.



## To Do

* Auto create node when creating an AR, instead of lazily-creating it
* `after_update` to update a node/relationship.
* Allow to disable sub reference nodes through options
* Execute queries/scripts from model and not Neography (e.g. `Movie.neo_gremlin(gremlin_query)` with query that outputs IDs, returns a list of `Movie`s)

---

developed by [@elado](http://twitter.com/elado) | named by [@ekampf](http://twitter.com/ekampf)