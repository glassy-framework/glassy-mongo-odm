require "./spec_helper"
require "./spec_helper/sample_app/src/app_kernel"

describe Glassy::MongoODM::Migration do
  it "has name and time" do
    Dir.cd "#{__DIR__}/spec_helper/sample_app" do
      kernel = AppKernel.new
      migration = MyName0.new(kernel.container.db_connection, kernel.container)
      migration.name.should eq "my_name_0"
      migration.created_at.should eq Time.unix(0)

      migration = MyName1.new(kernel.container.db_connection, kernel.container)
      migration.name.should eq "my_name_1"
      migration.created_at.should eq Time.unix(1)
    end
  end
end
