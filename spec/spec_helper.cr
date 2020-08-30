require "spec"
require "../src/glassy-mongo-odm"

def make_connection
  db_name = "default_db"
  conn = Glassy::MongoODM::Connection.new("mongodb://mongo", db_name)
  conn.client[db_name].drop
  conn
end
