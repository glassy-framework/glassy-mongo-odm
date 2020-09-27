require "glassy-console"
require "../migration_utils"
require "../migration_repository"
require "../migration_document"
require "../ext/container"

module Glassy::MongoODM::Commands
  class Migrate < Glassy::Console::Command
    property name : String = "db:migrate"
    property description : String = "Run all migration files"

    def initialize(
      @input : Input,
      @output : Output,
      @container : Glassy::Kernel::Container,
      @repository : Glassy::MongoODM::MigrationRepository
    )
    end

    def execute
      executed_migrations = @repository.find_all.map { |m| m.name }.to_a

      @container.migration_list.sort_by { |m| m.created_at.as(Time) }.each do |migration|
        if executed_migrations.includes? migration.name
          output.writeln("#{migration.name}: already migrated")
        else
          migration.up
          document = MigrationDocument.new(migration.name)
          @repository.save(document)
          output.writeln("#{migration.name}: migrated with success", :green)
        end
      end
    end
  end
end
