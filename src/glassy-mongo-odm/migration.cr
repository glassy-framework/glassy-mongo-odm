require "glassy-kernel"
require "./connection"

module Glassy::MongoODM
  abstract class Migration
    def initialize(@connection : Connection, @container : Glassy::Kernel::Container)
    end

    abstract def up
    abstract def created_at : Time
    abstract def name : String
  end
end
