require "mongo"
require "./spec_helper"
require "./fixtures/collection"
require "./fixtures/repository_classes"

describe Glassy::MongoODM::Repository do
  it "to_bson" do
    connection = make_connection()
    repository = UserRepository.new(connection)

    user = make_user
    user.id = BSON::ObjectId.new
    user.identities.not_nil![0].id = BSON::ObjectId.new

    repository.to_bson(user).should eq ({
      "_id"         => user.id,
      "Name"        => "Joe Doe",
      "always_null" => nil,
      "birth_date"  => user.birth_date,
      "mother"      => {
        "name" => "Alice",
      },
      "phones" => [
        "(00) 111",
        "(11) 000",
      ],
      "identities" => [
        {
          "_id"    => user.identities.not_nil![0].id,
          "type"   => 1,
          "number" => 5,
        },
      ],
    }).to_bson
  end

  it "from_bson" do
    connection = make_connection()
    repository = UserRepository.new(connection)

    user_id = BSON::ObjectId.new
    identity_id = BSON::ObjectId.new

    user = repository.from_bson({
      "_id"         => user_id,
      "Name"        => "Joe Doe",
      "always_null" => nil,
      "mother"      => {
        "name" => "Alice",
      },
      "phones" => [
        "(00) 111",
        "(11) 000",
      ],
      "identities" => [
        {
          "_id"    => identity_id,
          "type"   => 1,
          "number" => 5,
        },
      ],
    }.to_bson)

    user.id.should eq user_id
    user.name.should eq "Joe Doe"
    user.always_null.should be_nil
    user.mother.not_nil!.name.should eq "Alice"
    user.phones.size.should eq 2
    user.phones[0].should eq "(00) 111"
    user.phones[1].should eq "(11) 000"
    user.identities.not_nil!.size.should eq 1
    user.identities.not_nil![0].id.should eq identity_id
    user.identities.not_nil![0].type.should eq Identity::IdentityType::Passport
    user.identities.not_nil![0].number.should eq 5
  end

  it "from_bson with required fields" do
    connection = make_connection()
    repository = RequiredEntityRepository.new(connection)

    id = BSON::ObjectId.new
    birth_date = Time.local(2016, 2, 15, 10, 20, 30, location: Time::Location.load("Europe/Berlin"))

    entity = repository.from_bson({
      "_id"        => id,
      "type"       => 1,
      "name"       => "My name",
      "has_child"  => true,
      "number"     => 42,
      "price"      => 52.42,
      "birth_date" => birth_date,
      "numbers"    => [1, 2, 3],
    }.to_bson)

    entity.id.should eq id
    entity.type.should eq Identity::IdentityType::Passport
    entity.name.should eq "My name"
    entity.has_child.should eq true
    entity.number.should eq 42
    entity.price.should eq 52.42
    entity.birth_date.should eq birth_date
    entity.numbers.should eq [1, 2, 3]
  end

  it "from_bson with empty bson" do
    connection = make_connection()
    repository = RequiredEntityRepository.new(connection)

    birth_date = Time.local(2016, 2, 15, 10, 20, 30, location: Time::Location.load("Europe/Berlin"))

    entity = repository.from_bson({"have" => "nothing"}.to_bson)

    entity.id.should_not be_nil
    entity.type.should eq Identity::IdentityType::Id
    entity.name.should eq ""
    entity.has_child.should eq false
    entity.number.should eq 0
    entity.price.should eq 0.0
    entity.birth_date.should eq Time.unix(0)
    entity.numbers.should eq [] of Int32
    entity.enabled.should be_true

    entity = repository.from_bson({"enabled" => false}.to_bson)
    entity.enabled.should be_false
  end

  it "from_bson with nillable and false value" do
    connection = make_connection()
    repository = NillableEntityRepository.new(connection)

    entity = repository.from_bson({"enabled" => false}.to_bson)

    entity.id.should_not be_nil
    entity.enabled.should eq false

    entity = repository.from_bson({"enabled" => nil}.to_bson)

    entity.id.should_not be_nil
    entity.enabled.should be_nil

    entity = repository.from_bson({"have" => "nothing"}.to_bson)

    entity.id.should_not be_nil
    entity.enabled.should be_true
  end

  it "insert document & find by id" do
    connection = make_connection()
    repository = UserRepository.new(connection)

    repository.collection_name.should eq("user")

    user = make_user

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

      identity = user.identities.not_nil![0]

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
    identities.all? { |i| i.type == Identity::IdentityType::Id }.should be_true
  end

  it "update" do
    connection = make_connection()
    repository = IdentityRepository.new(connection)

    identity1 = Identity.new
    identity1.type = Identity::IdentityType::Id
    identity1.number = 1

    repository.save(identity1)

    identities = repository.find_all.to_a
    identities.size.should eq 1
    identities.first.number.should eq 1

    identity2 = identities.first.not_nil!
    identity2.number = 2
    repository.save(identity2)

    repository.collection.last_update.should eq ({
      "$set" => {
        "number" => 2,
      },
    }.to_bson)

    identities = repository.find_all.to_a
    identities.size.should eq 1
    identities.first.number.should eq 2
  end

  it "remove" do
    connection = make_connection()
    repository = IdentityRepository.new(connection)

    identity1 = Identity.new
    identity1.type = Identity::IdentityType::Id
    identity1.number = 1

    repository.save(identity1)

    identities = repository.find_all.to_a
    identities.size.should eq 1
    identities.first.number.should eq 1

    repository.remove(identity1.id.not_nil!)

    identities = repository.find_all.to_a
    identities.size.should eq 0
  end
end

def make_user
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

  user
end
