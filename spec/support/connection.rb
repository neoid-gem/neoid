ActiveRecord::Base.establish_connection :adapter=> "sqlite3", :database=> File.join(File.dirname(__FILE__), "db/test.sqlite3")
