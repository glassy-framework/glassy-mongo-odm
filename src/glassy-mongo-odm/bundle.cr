require "glassy-kernel"

module Glassy::MongoODM
  class Bundle < Glassy::Kernel::Bundle
    SERVICES_PATH = "#{__DIR__}/config/services.yml"

    HAS_CONTAINER_EXT = true

    macro apply_container_ext(all_bundles)
      def db_migration_list(context : Glassy::Kernel::Context? = nil) : Array(Glassy::MongoODM::Migration)
        [
          {% for bundle in all_bundles %}
            {% if migration_path = bundle.resolve.constant("MIGRATIONS_PATH") %}
              {{ run("#{__DIR__}/list_migrations", migration_path) }}
            {% end %}
          {% end %}
        ] of Glassy::MongoODM::Migration
      end
    end
  end
end
