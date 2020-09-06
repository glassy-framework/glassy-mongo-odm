require "glassy-console"
require "../migration_utils"

module Glassy::MongoODM::Commands
  class MakeMigration < Glassy::Console::Command
    property name : String = "db:make-migration"
    property description : String = "Make migration file"

    def initialize(
      @input : Input,
      @output : Output,
      @kernel : Glassy::Kernel::Kernel
    )
    end

    @[Argument(name: "name", desc: "name of the migration")]
    @[Option(name: "bundle", desc: "bundle where that migration will be created")]
    def execute(name : String, bundle : String)
      bundle_metadata = @kernel.bundles.select { |b| b.name == bundle }.first?

      if bundle_metadata.nil?
        output.error("The bundle #{bundle} does not exists")
        return
      end

      migrations_path = bundle_metadata.metadata["MIGRATIONS_PATH"]?

      if migrations_path.nil?
        output.error("The bundle #{bundle} does not define migrations path")
        return
      end

      if !File.exists?(migrations_path)
        output.error("The path #{migrations_path} does not exists")
        return
      end

      utils = MigrationUtils.new
      time = Time.utc

      content = <<-END
      require "glassy-mongo-odm"

      class #{utils.create_class_name(name, time)} < Glassy::MongoODM::Migration
        def up
          # use @connection : Glassy::MongoODM::Connection
        end

        def name : String
          "#{utils.create_file_name(name, time).sub(".cr", "")}"
        end

        def created_at : Time
          Time.unix #{time.to_unix}
        end
      end
      END

      full_filename = "#{migrations_path}/#{utils.create_file_name(name, time)}"

      File.write(full_filename, content)

      relative_filename = full_filename.sub(Dir.current + "/", "")
      output.writeln("Created #{relative_filename}")
      output.writeln("Dont forget to require all migrations files")
    end
  end
end
