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