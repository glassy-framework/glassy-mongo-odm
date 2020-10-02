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

struct BSON::ObjectId
  def to_s
    buf = StaticArray(UInt8, 25).new(0_u8)
    LibBSON.bson_oid_to_string(@handle, buf)
    String.new(buf.to_slice).rstrip('\u0000')
  end
end
