require "mongo"

module Mongo
  class Collection
    property last_update : BSON?

    def update(selector, update, flags = LibMongoC::UpdateFlags::NONE, write_concern = nil)
      previous_def

      @last_update = update.to_bson
    end
  end
end
