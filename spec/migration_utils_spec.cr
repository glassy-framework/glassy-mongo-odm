require "./spec_helper"

describe Glassy::MongoODM::MigrationUtils do
  it "create_class_name" do
    time = Time.unix(100)
    utils = Glassy::MongoODM::MigrationUtils.new
    utils.create_class_name("My Test", time).should eq "MyTest100"
  end

  it "create_file_name" do
    time = Time.unix(100)
    utils = Glassy::MongoODM::MigrationUtils.new
    utils.create_file_name("My Test", time).should eq "my_test_100.cr"
  end

  it "get_class_name_from_file_name" do
    time = Time.unix(100)
    utils = Glassy::MongoODM::MigrationUtils.new
    utils.get_class_name_from_file_name("src/bundle/migrations/my_test_100.cr")
      .should eq "MyTest100"
  end
end
