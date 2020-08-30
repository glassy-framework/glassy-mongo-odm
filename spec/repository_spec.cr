require "./spec_helper"
require "mongo"

alias ODM = Glassy::MongoODM::Annotations

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

class UserRepository < Glassy::MongoODM::Repository(Entity::User)
end

class IdentityRepository < Glassy::MongoODM::Repository(Identity)
end

describe Glassy::MongoODM::Repository do
  it "insert document & find by id" do
    connection = make_connection()
    repository = UserRepository.new(connection)

    repository.collection_name.should eq("user")

    mother = Entity::User::Mother.new
    mother.name = "Alice"

    identity = Identity.new
    identity.type = Identity::IdentityType::Passport
    identity.number = 5

    user = Entity::User.new
    user.name = "Joe Doe"
    user.birth_date = Time.local(2016, 2, 15, 10, 20, 30, location: Time::Location.load("Europe/Berlin"))
    user.mother = mother
    user.phones = ["(00) 111", "(11) 000"]
    user.identities = [identity]

    repository.save(user)

    user.id.should_not be_nil
    user.always_null.should be_nil

    new_user = repository.find_by_id(user.id.not_nil!)
    new_user.should_not be nil

    unless new_user.nil?
      new_user.id.should eq user.id
      new_user.name.should eq user.name
      new_user.always_null.should be_nil
      new_user.birth_date.should eq user.birth_date
      new_user.mother.should_not eq nil
      new_user.phones.should eq user.phones
      new_user.identities.should_not eq nil

      if new_user.mother && user.mother
        new_user.mother.not_nil!.name.should eq user.mother.not_nil!.name
      end

      new_user.identities.not_nil!.size.should eq 1
      new_identity = new_user.identities.not_nil!.first
      new_identity.type.should eq identity.type
      new_identity.number.should eq identity.number
    end
  end

  it "find with cursor" do
    identity1 = Identity.new
    identity1.type = Identity::IdentityType::Id
    identity1.number = 1

    identity2 = Identity.new
    identity2.type = Identity::IdentityType::Id
    identity2.number = 2

    identity3 = Identity.new
    identity3.type = Identity::IdentityType::Passport
    identity3.number = 3

    connection = make_connection()
    repository = IdentityRepository.new(connection)

    repository.save(identity1)
    repository.save(identity2)
    repository.save(identity3)

    identities = repository.find_by({"type" => Identity::IdentityType::Id})
    identities.size.should eq 2
    identities.all?{|i| i.type == Identity::IdentityType::Id}.should be_true
  end
end
