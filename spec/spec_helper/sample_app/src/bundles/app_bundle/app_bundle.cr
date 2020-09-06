require "./services/**"
require "./migrations/**"
require "../../../../../spec_helper"

class AppBundle < Glassy::Kernel::Bundle
  SERVICES_PATH = "#{__DIR__}/config/services.yml"
  MIGRATIONS_PATH = "#{__DIR__}/migrations"
end
