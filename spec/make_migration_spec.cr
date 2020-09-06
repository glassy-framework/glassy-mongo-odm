require "./spec_helper"
require "./spec_helper/sample_app/src/app_kernel"
require "glassy-console"

describe Glassy::MongoODM::Commands::MakeMigration do
  it "alert empty migrations path" do
    Dir.cd "#{__DIR__}/spec_helper/sample_app" do
      input = Glassy::Console::ArrayInput.new([] of String)
      output = Glassy::Console::ArrayOutput.new
      kernel = AppKernel.new
      command = Glassy::MongoODM::Commands::MakeMigration.new(input, output, kernel)
      command.execute_arguments(["My Name", "--bundle", "OtherBundle"])
      output.items.join("\n").should contain("does not define migrations path")
    end
  end

  it "alert not found bundle" do
    Dir.cd "#{__DIR__}/spec_helper/sample_app" do
      input = Glassy::Console::ArrayInput.new([] of String)
      output = Glassy::Console::ArrayOutput.new
      kernel = AppKernel.new
      command = Glassy::MongoODM::Commands::MakeMigration.new(input, output, kernel)
      command.execute_arguments(["My Name", "--bundle", "NotExists"])
      output.items.join("\n").should contain("does not exists")
    end
  end

  it "create migration file" do
    Dir.cd "#{__DIR__}/spec_helper/sample_app" do
      input = Glassy::Console::ArrayInput.new([] of String)
      output = Glassy::Console::ArrayOutput.new
      kernel = AppKernel.new
      command = Glassy::MongoODM::Commands::MakeMigration.new(input, output, kernel)
      command.execute_arguments(["My Name", "--bundle", "AppBundle"])
      file_suffix = Time.utc.to_unix
      output.items.should eq [
        "Created src/bundles/app_bundle/migrations/my_name_#{file_suffix}.cr",
        "Dont forget to require all migrations files"
      ]

      content = File.read("src/bundles/app_bundle/migrations/my_name_#{file_suffix}.cr")
      expected_content = <<-END
      require "glassy-mongo-odm"

      class MyName#{file_suffix} < Glassy::MongoODM::Migration
        def up
          # use @connection : Glassy::MongoODM::Connection
        end

        def name : String
          "my_name_#{file_suffix}"
        end

        def created_at : Time
          Time.unix #{file_suffix}
        end
      end
      END

      content.should eq expected_content

      File.delete("src/bundles/app_bundle/migrations/my_name_#{file_suffix}.cr")
    end
  end
end
