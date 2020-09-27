require "mongo"
require "json"

class BSON
  def []=(key, value : Enum)
    self[key] = value.value
  end
end

def BSON::ObjectId.new(pull : JSON::PullParser)
  new(pull.read_string)
end
