class MyName1 < Glassy::MongoODM::Migration
  def up
    # use @connection : Glassy::MongoODM::Connection
  end

  def name : String
    "my_name_1"
  end

  def created_at : Time
    Time.unix 1
  end
end
