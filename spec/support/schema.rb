ActiveRecord::Schema.define :version => 0 do
  # enable JSON field to be created (Matching PostgreSQL 9.2 and up)
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table :users do |t|
    t.string :name
    t.string :slug

    t.timestamps
  end

  create_table :movies do |t|
    t.string :name
    t.string :slug
    t.integer :year

    t.timestamps
  end

  create_table :likes do |t|
    t.integer :user_id
    t.integer :movie_id
    t.integer :rate

    t.timestamps
  end


  create_table :articles do |t|
    t.string :title
    t.string :body
    t.integer :year

    t.timestamps
  end

  create_table :user_follows do |t|
    t.belongs_to :user
    t.belongs_to :item, polymorphic: true

    t.timestamps
  end

  create_table :no_auto_index_nodes do |t|
    t.string :name
  end

  create_table :node_with_jsons do |t|
    t.json :data
    t.string :node_type
  end
end
