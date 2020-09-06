require "./glassy-mongo-odm/commands/**"
require "./glassy-mongo-odm/exceptions/**"
require "./glassy-mongo-odm/ext/**"
require "./glassy-mongo-odm/annotations"
require "./glassy-mongo-odm/bson_diff"
require "./glassy-mongo-odm/bundle"
require "./glassy-mongo-odm/connection"
require "./glassy-mongo-odm/entity_proxy"
require "./glassy-mongo-odm/migration"
require "./glassy-mongo-odm/migration_document"
require "./glassy-mongo-odm/migration_repository"
require "./glassy-mongo-odm/migration_utils"
require "./glassy-mongo-odm/repository"

module Glassy::MongoODM
  VERSION = "0.1.0"
end
