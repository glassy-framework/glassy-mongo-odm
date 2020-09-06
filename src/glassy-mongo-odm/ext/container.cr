require "../migration"

module Glassy::Kernel
  abstract class Container
    abstract def migration_list : Array(Glassy::MongoODM::Migration)
  end
end
