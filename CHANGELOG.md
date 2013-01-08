## v0.1.1

* Added batch support, for much faster intiialization of current DB or reindexing all DB.
* Dropped indexes per model, instead, using `node_auto_index` and `relationship_auto_index`, letting Neo4j auto index objects.
* One `neo_save` method instead of `neo_create` and `neo_update`. It takes care of inserting or updating.

### Breaking changes:

Model indexes (such as `users_index`) are now turned off by default. Instead, Neoid uses Neo4j's auto indexing feature.

In order to have the model indexes back, use this in your configuration:

```ruby
Neoid.configure do |c|
  c.enable_per_model_indexes = true
end
```

This will turn on for all models.

You can turn off for a specific model with:

```ruby
class User < ActiveRecord::Base
  include Neoid::Node
  
  neoidable enable_model_index: false do |c|
  end
end
```

## v0.0.51

* Releasing Neoid as a gem.

## v0.0.41

* fixed really annoying bug caused by Rails design -- Rails doesn't call `after_destroy` when assigning many to many relationships to a model, like `user.movies = [m1, m2, m3]` or `user.update_attributes(params[:user])` where it contains `params[:user][:movie_ids]` list (say from checkboxes), but it DOES CALL after_create for the new relationships. the fix adds after_remove callback to the has_many relationships, ensuring neo4j is up to date with all changes, no matter how they were committed

## v0.0.4

* rewrote seacrch. one index for all types instead of one for type. please run neo_search_index on all of your models.
  search in multiple types at once with `Neoid.search(types_array, term)

## v0.0.3

* new configuration syntax (backwards compatible)
* full text search index

## v0.0.2

* create node immediately after active record create
* logging
* bug fixes

## v0.0.1

* initial release