require "glassy-kernel"
require "./connection"

module Glassy::MongoODM
  abstract class Migration
    def initialize(@connection : Connection, @container : Glassy::Kernel::Container)
    end

    abstract def up
    abstract def name : String
    abstract def created_at : Time

    macro inherited
      def name : String
        "{{ @type.name.gsub(/([a-z])([A-Z0-9])/, "\\1_\\2").downcase }}"
      end

      def created_at : Time
        Time.unix({{ @type.name.gsub(/[a-zA-Z_]/,"") }})
      end
    end
  end
end
