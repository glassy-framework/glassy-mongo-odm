require "./repository"
require "./migration_document"

module Glassy::MongoODM
  class MigrationRepository < Repository(MigrationDocument)
  end
end
