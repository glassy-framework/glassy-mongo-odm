require "../migration"

module Glassy::Kernel
  abstract class Container
    abstract def db_migration_list : Array(Glassy::MongoODM::Migration)
  end
end
