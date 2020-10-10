require "./spec_helper"
require "./spec_helper/sample_app/src/app_kernel"
require "glassy-console"

describe Glassy::MongoODM::Commands::Migrate do
  it "run migrations" do
    Dir.cd "#{__DIR__}/spec_helper/sample_app" do
      input = Glassy::Console::ArrayInput.new([] of String)
      output = Glassy::Console::ArrayOutput.new
      kernel = AppKernel.new

      repository = kernel.container.db_migration_repository

      command = Glassy::MongoODM::Commands::Migrate.new(
        input,
        output,
        kernel.container,
        repository
      )

      if repository.collection.count > 0
        repository.collection.drop
      end

      command.execute_arguments([] of String)

      output.items.should eq [
        "my_name_0: migrated with success",
        "my_name_1: migrated with success",
      ]

      repository.find_all.map { |m| m.name }.to_a.should eq ["my_name_0", "my_name_1"]

      output.clear

      command.execute_arguments([] of String)

      output.items.should eq [
        "my_name_0: already migrated",
        "my_name_1: already migrated",
      ]
    end
  end
end
