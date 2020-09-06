class MyName0 < Glassy::MongoODM::Migration
  def up
    # use @connection : Glassy::MongoODM::Connection
  end

  def name : String
    "my_name_0"
  end

  def created_at : Time
    Time.unix 0
  end
end
