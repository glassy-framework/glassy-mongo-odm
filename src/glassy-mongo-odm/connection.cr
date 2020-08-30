require "mongo"

module Glassy::MongoODM
  class Connection
    getter default_database

    @client : Mongo::Client?

    def initialize(@conn_string : String, @default_database : String)
    end

    private def connect : Mongo::Client
      @client = Mongo::Client.new @conn_string
    end

    def client : Mongo::Client
      if @client.nil?
        return connect()
      end

      @client.not_nil!
    end
  end
end
