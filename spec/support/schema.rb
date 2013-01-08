ActiveRecord::Schema.define :version => 0 do
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
end
