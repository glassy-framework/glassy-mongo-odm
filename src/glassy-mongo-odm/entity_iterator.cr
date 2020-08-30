require "./repository"

module Glassy::MongoODM
  class EntityIterator(T)
    include Iterator(T)

    def initialize(
      @mongo_cursor : Mongo::Cursor,
      @repository : Repository(T),
      @rewind_proc : Proc(Mongo::Cursor)
    )
    end

    def next
      if next_bson = @mongo_cursor.next
        @repository.from_bson(next_bson)
      else
        stop
      end
    end

    def rewind
      @mongo_cursor.finalize
      @mongo_cursor = @rewind_proc.call
    end
  end
end
