require "mongo"
require "../spec_helper"

include Glassy::MongoODM::Annotations

module Entity
  @[ODM::Document]
  class User
    @[ODM::Id]
    property id : BSON::ObjectId?

    @[ODM::Field(name: "Name")]
    property name : String?

    @[ODM::Field]
    property always_null : Int32?

    @[ODM::Field]
    property birth_date : Time?

    @[ODM::Field]
    property mother : Mother?

    @[ODM::Field]
    property phones : Array(String) = [] of String

    @[ODM::Field]
    property identities : Array(Identity)?

    @[ODM::Document]
    class Mother
      @[ODM::Field]
      property name : String?
    end
  end
end

@[ODM::Document]
class Identity
  @[ODM::Id]
  property id : BSON::ObjectId?

  @[ODM::Field]
  property type : IdentityType?

  @[ODM::Field]
  property number : Int32?

  enum IdentityType
    Id
    Passport
  end
end

@[ODM::Document]
class RequiredEntity
  @[ODM::Id]
  property id : BSON::ObjectId

  @[ODM::Field]
  property type : Identity::IdentityType

  @[ODM::Field]
  property name : String

  @[ODM::Field]
  property has_child : Bool

  @[ODM::Field]
  property number : Int32

  @[ODM::Field]
  property price : Float64

  @[ODM::Field]
  property birth_date : Time

  @[ODM::Field]
  property numbers : Array(Int32)

  @[ODM::Field]
  property enabled : Bool = true

  @[ODM::Initialize]
  def initialize(@type, @name, @has_child, @number, @price, @birth_date, @numbers, @enabled)
    @id = BSON::ObjectId.new
  end
end

@[ODM::Document]
class NillableEntity
  @[ODM::Id]
  property id : BSON::ObjectId?

  @[ODM::Field]
  property enabled : Bool? = true
end

class UserRepository < Glassy::MongoODM::Repository(Entity::User)
end

class IdentityRepository < Glassy::MongoODM::Repository(Identity)
end

class RequiredEntityRepository < Glassy::MongoODM::Repository(RequiredEntity)
end

class NillableEntityRepository < Glassy::MongoODM::Repository(NillableEntity)
end
