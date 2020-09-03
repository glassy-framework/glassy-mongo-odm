require "mongo"

module Glassy::MongoODM
  class BSONDiff
    def diff(old : BSON, new : BSON) : BSON?
      set = {} of String => BSON::Field
      add_set_diff(old, new, [] of String, set)

      unset = {} of String => BSON::Field
      add_unset_diff(old, new, [] of String, unset)

      result = {} of String => Hash(String, BSON::Field)

      unless set.empty?
        result["$set"] = set
      end

      unless unset.empty?
        result["$unset"] = unset
      end

      unless result.empty?
        return result.to_bson
      end

      return nil
    end

    def add_set_diff(old : BSON, new : BSON, path : Array(String), set : Hash(String, BSON::Field))
      new.each_pair do |key, value|
        full_key = path.dup.push(key).join(".")
        deep = false

        if should_deep_change?(old, new, key)
          add_set_diff(old[key].as(BSON), value.value.as(BSON), path.dup.push(key), set)
        else
          if value.value != old[key]?
            if value.value.is_a?(BSON) && value.value.as(BSON).array?
              item_list = [] of BSON::Field
              value.value.as(BSON).each do |v|
                item_list << v.value
              end
              set[full_key] = item_list
            else
              set[full_key] = value.value
            end
          end
        end
      end
    end

    def add_unset_diff(old : BSON, new : BSON, path : Array(String), unset : Hash(String, BSON::Field))
      old.each_pair do |key, value|
        full_key = path.dup.push(key).join(".")
        deep = false

        if should_deep_change?(old, new, key)
          add_unset_diff(value.value.as(BSON), new[key].as(BSON), path.dup.push(key), unset)
        else
          begin
            new[key]
          rescue IndexError
            unset[full_key] = ""
          end
        end
      end
    end

    def should_deep_change?(old : BSON, new : BSON, key : String) : Bool
      if new[key]?.is_a?(BSON) && old[key]?.is_a?(BSON)
        if old[key].as(BSON).array? && new[key].as(BSON).array?
          return old[key].as(BSON).size == new[key].as(BSON).size
        else
          return true
        end
      end

      return false
    end
  end
end
