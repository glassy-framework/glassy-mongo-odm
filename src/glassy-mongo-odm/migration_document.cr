require "mongo"
require "./annotations"

module Glassy::MongoODM
  @[Annotations::ODM::Document(collection: "migration")]
  class MigrationDocument
    @[Annotations::ODM::Id]
    property id : BSON::ObjectId?

    @[Annotations::ODM::Field]
    property name : String

    @[Annotations::ODM::Initialize]
    def initialize(@name)
    end
  end
end
