class BSON
  def []=(key, value : Enum)
    self[key] = value.value
  end
end
