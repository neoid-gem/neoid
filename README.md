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

In an initializer, such as `config/initializers/neo4j.rb`:

	neo4j_uri_string = ENV["NEO4J_URL"] || "http://localhost:7474/"
    $neo = Neography::Rest.new(neo4j_uri_string)

    neo4j_uri = URI.parse(neo4j_uri_string)

    Neography::Config.tap do |c|
      c.server = neo4j_uri.host
      c.port = neo4j_uri.port

      if neo4j_uri.user && neo4j_uri.password
        c.authentication = 'basic'
        c.username = neo4j_uri.user
        c.password = neo4j_uri.password
      end
    end

    Neoid.db = $neo


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

Let's assume that a `User` can have `Categories`:


	# user.rb

	class User < ActiveRecord::Base
      include Neoid::Node
    
	  has_many :user_categories
      has_many :categories, through: :user_categories
    
	  def to_neo
        neo_properties_to_hash(%w(slug display_name))
	  end
	end


	# category.rb

	class Category < ActiveRecord::Base
      include Neoid::Node
    
	  has_many :user_categories
      has_many :users, through: :user_categories
    
	  def to_neo
        neo_properties_to_hash(%w(slug name))
	  end
	end


	# user_category.rb

	class UserCategory < ActiveRecord::Base
	  belongs_to :user
      belongs_to :category
	end



Now let's make the `UserCategory` model a Neoid, by including the `Neoid::Relationship` module, and define the relationship (start & end nodes and relationship type) options with `neoidable` method:


	class UserCategory < ActiveRecord::Base
	  belongs_to :user
	  belongs_to :category

	  include Neoid::Relationship
	  neoidable start_node: :user, end_node: :category, type: :categorized
	end


Neoid adds `neo_node` and `neo_relationships` to nodes and relationships, respectively.

So you could do:

	user = User.create!(display_name: "elado")
	user.categories << Category.create("Development")
	user.categories << Category.create("Music")

	user.neo_node                # => #<Neography::Node…>
	user.neo_node.display_name   # => "elado"


## Querying

You can query with all [Neography](https://github.com/maxdemarzi/neography)'s API: `traverse`, `execute_query` for Cypher, and `execute_script` for Gremlin.

### Gremlin Example:

These examples query Neo4j using Gremlin for IDs of objects, and then fetches them from ActiveRecord with an `in` query.

Of course, you can store using the `to_neo` all the data you need in Neo4j and avoid querying ActiveRecord.


**Most popular categories**

	gremlin_query = <<-GREMLIN
	  m = [:]

	  g.v(0)
	    .out('categories_subref').out
          .inE('categorized')
          .inV
          .groupCount(m).iterate()

	  m.sort{-it.value}.collect{it.key.ar_id}
	GREMLIN

	category_ids = $neo.execute_script(gremlin_query)

	Category.where(id: recommended_product_ids)


Assuming we have another `Friendship` model which is a relationship with start/end nodes of `user` and type of `friends`,

**Categories of user friends that the user doesn't have**

	user = User.find(1)

	gremlin_query = <<-GREMLIN
	  u = g.idx('users_index')[[ar_id:'#{user.id}']][0].toList()[0]
	  categories = []

	  u
		.out('categorized').aggregate(categories).back(2)
	    .out('friends').out('categories')
		.dedup
		.except(categories).collect{it.ar_id}
	GREMLIN

	category_ids = $neo.execute_script(gremlin_query)

	Category.where(id: recommended_product_ids)


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



## TODO

* `after_update` to update a node/relationship.
* allow to disable sub reference nodes