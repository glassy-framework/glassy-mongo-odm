# glassy-mongo-odm

[![CircleCI](https://circleci.com/gh/glassy-framework/glassy-mongo-odm.svg?style=svg)](https://circleci.com/gh/glassy-framework/glassy-mongo-odm)

Mongo ODM (Object Document Mapper) with repositories for crystal lang

## TODO
- [x] Serialize & Deserialize
- [ ] Connection Pool
- [ ] Thread Safety

Currently, in the container, we are creating several instances

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     glassy-mongodb-odm:
       github: glassy-framework/glassy-mongo-odm
   ```

2. Run `shards install`

## Usage

```crystal
require "glassy-mongo-odm"

include Glassy::MongoODM::Annotations

@[ODM::Document]
class User
  @[ODM::Id]
  property id : BSON::ObjectId?

  @[ODM::Field(name: "Name")]
  property name : String

  @[ODM::Field]
  property birth_date : Time

  @[ODM::Field]
  property mother : Mother?

  @[ODM::Document]
  class Mother
    @[ODM::Field]
    property name : String?
  end

  def initialize(@name, @birth_date)
  end
end

class UserRepository < Glassy::MongoODM::Repository(User)
end

conn = Glassy::MongoODM::Connection.new("mongodb://mongo", db_name)

repository = UserRepository.new(conn)

user = User.new(name: "My Name", birth_date: Time.local)

repository.save(user)

```

## Development

Always run crystal spec before submiting code

## Contributing

1. Fork it (<https://github.com/glassy-framework/glassy-mongo-odm/fork>)
2. Create your feature branch (`git checkout -b feature/my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Anderson Danilo](https://github.com/andersondanilo) - creator and maintainer
