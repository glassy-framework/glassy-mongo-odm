module Glassy::MongoODM
  class MigrationUtils
    def create_class_name(name : String, time : Time)
      name.gsub(" ", "_").camelcase + time.to_unix.to_s
    end

    def create_file_name(name : String, time : Time)
      name.gsub(" ", "_").downcase + "_" + time.to_unix.to_s + ".cr"
    end

    def get_class_name_from_file_name(filename : String) : String
      filename
        .split(File::SEPARATOR)
        .pop
        .sub(".cr", "")
        .camelcase
    end
  end
end
