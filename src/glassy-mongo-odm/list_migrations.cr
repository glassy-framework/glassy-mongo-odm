require "./migration_utils"

path = ARGV[0]
utils = Glassy::MongoODM::MigrationUtils.new

Dir.entries(path).each do |filename|
  if filename =~ /\d+\.cr$/
    class_name = utils.get_class_name_from_file_name(filename)
    puts "#{class_name}.new(db_connection, container),"
  end
end
