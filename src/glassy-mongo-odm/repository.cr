require "./connection"
require "./annotations"
require "./ext/bson"
require "./entity_iterator"
require "mongo"

module Glassy::MongoODM
  abstract class Repository(EntityClass)
    include Glassy::MongoODM::Annotations

    abstract def to_bson(entity : EntityClass, is_update : Bool) : BSON
    abstract def from_bson(bson : BSON) : EntityClass
    abstract def collection_name : String
    abstract def database_name : String

    def initialize(@connection : Glassy::MongoODM::Connection)
    end

    def save(entity : EntityClass) : Void
      is_update = !primary_key(entity).nil?

      payload = to_bson(entity, is_update)
      collection = @connection.client[database_name][collection_name]

      if is_update
        collection.save(payload)
      else
        collection.insert(payload)
        id = payload["_id"]

        if id.is_a?(BSON::ObjectId)
          entity.id = id.as(BSON::ObjectId)
        end
      end
    end

    def find_by_id(id : BSON::ObjectId): EntityClass?
      find_one_by({"_id" => id})
    end

    def find_by_id!(id : BSON::ObjectId): EntityClass
      find_by_id(id).not_nil!
    end

    def find_one_by(query : Hash): EntityClass?
      collection = @connection.client[database_name][collection_name]
      bson = collection.find_one(query)

      unless bson.nil?
        return from_bson(bson)
      end

      return nil
    end

    def find_one_by!(query : Hash): EntityClass
      find_one_by(query).not_nil!
    end

    def find_by(query : Hash): EntityIterator(EntityClass)
      collection = @connection.client[database_name][collection_name]
      make_mongo_cursor = -> { collection.find(query) }
      mongo_cursor = make_mongo_cursor.call
      return EntityIterator.new(
        mongo_cursor,
        self,
        make_mongo_cursor
      )
    end

    macro inherited
      def to_bson(entity : EntityClass, is_update : Bool) : BSON
        proc = to_bson_macro({{@type.superclass.type_vars.first}})
        proc.call(entity, is_update)
      end

      macro to_bson_macro(klass_path)
        {% verbatim do %}
          ->(entity : {{klass_path}}, is_update : Bool) {
            %bson = BSON.new
            {% klass = klass_path.resolve %}
            {% for ivar in klass.instance_vars %}
              {% id_ann = ivar.annotation(Id) %}
              {% if id_ann %}
              %bson["_id"] = entity.{{ivar.name}} || BSON::ObjectId.new
              {% end %}

              {% field_ann = ivar.annotation(Field) %}
              {% if field_ann %}
                {% field_name = field_ann[:name] ? field_ann[:name].id : ivar.name %}
                {% transformed_value = false %}
                {% if ivar.type.is_a?(TypeNode) %}
                  {% for type in ivar.type.union_types %}
                    {% doc_ann = type.annotation(Document) %}
                    {% if doc_ann %}
                      %proc = to_bson_macro({{type}})
                      unless entity.{{ivar.name}}.nil?
                        %bson["{{field_name}}"] = %proc.call(entity.{{ivar.name}}.not_nil!, is_update)
                      end
                      {% transformed_value = true %}
                    {% end %}
                    {% if type.name =~ /Array/ %}
                      {% item_type = type.type_vars.first %}
                      {% doc_ann = item_type.annotation(Document) %}
                      unless entity.{{ivar.name}}.nil?
                        {% if doc_ann %}
                          %bson["{{field_name}}"] = entity.{{ivar.name}}.not_nil!.map {|item|
                            %proc = to_bson_macro({{item_type}})
                            %proc.call(item, false)
                          }.to_bson
                        {% else %}
                          %bson["{{field_name}}"] = entity.{{ivar.name}}.not_nil!.to_bson
                        {% end %}
                      end
                      {% transformed_value = true %}
                    {% end %}
                  {% end %}
                {% end %}
                {% unless transformed_value %}
                %bson["{{field_name}}"] = entity.{{ivar.name}}
                {% end %}
              {% end %}
            {% end %}
            return %bson
          }
        {% end %}
      end

      def from_bson(bson : BSON) : EntityClass
        proc = from_bson_macro({{@type.superclass.type_vars.first}})
        proc.call(bson)
      end

      macro from_bson_macro(klass_path)
        {% verbatim do %}
          ->(bson : BSON) {
            {% klass = klass_path.resolve %}
            %entity = {{klass.id}}.new

            {% for ivar in klass.instance_vars %}
              {% id_ann = ivar.annotation(Id) %}
              {% if id_ann %}
                %entity.{{ivar.name}} = bson["_id"].as(BSON::ObjectId)
              {% end %}

              {% field_ann = ivar.annotation(Field) %}
              {% if field_ann %}
                {% field_name = field_ann[:name] ? field_ann[:name].id : ivar.name %}
                begin
                  {% transformed_value = false %}
                  {% if ivar.type.is_a?(TypeNode) %}
                    {% for type in ivar.type.union_types %}
                      {% doc_ann = type.annotation(Document) %}
                      {% if doc_ann %}
                        %proc = from_bson_macro({{type}})
                        %entity.{{ivar.name}} = %proc.call(bson["{{field_name}}"].as(BSON))
                        {% transformed_value = true %}
                      {% end %}
                      {% if type.name =~ /Array/ %}
                        {% union_item_type = type.type_vars.join("|").id %}
                        {% first_item_type = type.type_vars.first %}
                        {% doc_ann = first_item_type.annotation(Document) %}
                        %value = [] of {{union_item_type}}
                        %bson_array = bson["{{field_name}}"]
                        if %bson_array.is_a?(BSON)
                          %bson_array.each do |v|
                            {% if doc_ann %}
                              %proc = from_bson_macro({{first_item_type}})
                              %value << %proc.call(v.value.as(BSON))
                            {% else %}
                              %value << v.value.as({{union_item_type}})
                            {% end %}
                          end
                        end
                        %entity.{{ivar.name}} = %value
                        {% transformed_value = true %}
                      {% end %}
                    {% end %}
                  {% end %}
                  {% unless transformed_value %}
                    {% enum_type = ivar.type.union_types.find{|t| t.ancestors.any?{|t2| t2.name =~ /^Enum$/ }} %}
                    {% if enum_type %}
                      unless bson["{{field_name}}"].nil?
                        %entity.{{ivar.name}} = {{enum_type}}.new(bson["{{field_name}}"].as(Int32))
                      end
                    {% else %}
                      %entity.{{ivar.name}} = bson["{{field_name}}"].as({{ ivar.type.id }})
                    {% end %}
                  {% end %}
                rescue IndexError
                  # Do Nothing
                end
              {% end %}
            {% end %}

            return %entity
          }
        {% end %}
      end

      def collection_name : String
        {% klass = @type.superclass.type_vars.first.resolve %}
        {% doc_ann = klass.annotation(Document) %}
        {% if doc_ann[:collection] %}
          {{doc_ann[:collection]}}
        {% else %}
          {{ klass.id.split("::").last.downcase }}
        {% end %}
      end

      def primary_key(entity : EntityClass) : BSON::ObjectId?
        primary_key_macro
      end

      macro primary_key_macro
        {% verbatim do %}
          pk = nil
          has_pk_field = false
          {% klass = @type.superclass.type_vars.first.resolve %}
          {% for ivar in klass.instance_vars %}
            {% id_ann = ivar.annotation(Id) %}
            {% if id_ann %}
              has_pk_field = true
              pk = entity.{{ivar.name}}
            {% end %}
          {% end %}

          unless has_pk_field
            raise "Entity without id field"
          end

          return pk
        {% end %}
      end

      def database_name : String
        @connection.default_database
      end
    end
  end
end
