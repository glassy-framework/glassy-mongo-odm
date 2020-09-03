require "mongo"

module Glassy::MongoODM
  module EntityProxy
    abstract def odm_original_bson : BSON?
  end
end
