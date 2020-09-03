require "./connection"
require "./annotations"
require "./ext/bson"
require "./bson_diff"
require "./entity_proxy"
require "./exceptions/**"
require "mongo"

module Glassy::MongoODM
  abstract class Repository(EntityClass)
    include Glassy::MongoODM::Annotations

    abstract def to_bson(entity : EntityClass) : BSON
    abstract def from_bson(bson : BSON) : EntityClass
    abstract def collection_name : String
    abstract def database_name : String
    abstract def find_by(query : Hash)
    abstract def get_primary_key(entity : EntityClass) : BSON::ObjectId?
    abstract def set_primary_key(entity : EntityClass, id : BSON::ObjectId)

    @collection : Mongo::Collection? = nil

    def initialize(@connection : Glassy::MongoODM::Connection)
    end

    def required_nil_defaults
      true
    end

    def collection : Mongo::Collection
      @collection ||= @connection.client[database_name][collection_name]
    end

    def save(entity : EntityClass) : Void
      new_bson = to_bson(entity)

      if entity.is_a?(EntityProxy)
        bson_diff = BSONDiff.new
        payload = bson_diff.diff(
          entity.as(EntityProxy).odm_original_bson.not_nil!,
          new_bson
        )
        unless payload.nil?
          collection.update({
            "_id" => get_primary_key(entity),
          }, payload)

          entity.as(EntityProxy).odm_original_bson = new_bson
        end
      else
        collection.save(new_bson)
        id = new_bson["_id"]

        if id.is_a?(BSON::ObjectId)
          set_primary_key(entity, id)
        end
      end
    end

    def remove(id : BSON::ObjectId) : Void
      collection.remove({
        "_id" => id,
      })
    end

    def find_by_id(id : BSON::ObjectId) : EntityClass?
      find_one_by({"_id" => id})
    end

    def find_by_id!(id : BSON::ObjectId) : EntityClass
      find_by_id(id).not_nil!
    end

    def find_one_by(query : Hash) : EntityClass?
      bson = collection.find_one(query)

      unless bson.nil?
        return from_bson(bson)
      end

      return nil
    end

    def find_one_by!(query : Hash) : EntityClass
      find_one_by(query).not_nil!
    end

    def find_all
      find_by({} of String => String)
    end

    macro inherited
      {% main_entity_type = @type.superclass.type_vars.first %}

      def find_by(query : Hash): EntityIterator
        make_mongo_cursor = -> { collection.find(query) }
        mongo_cursor = make_mongo_cursor.call
        return EntityIterator.new(
          mongo_cursor,
          self,
          make_mongo_cursor
        )
      end

      class CurrentEntityProxy < {{main_entity_type.id}}
        include Glassy::MongoODM::EntityProxy

        property odm_original_bson : BSON? = nil
      end

      class EntityIterator
        include Iterator({{main_entity_type.id}})

        def initialize(
          @mongo_cursor : Mongo::Cursor,
          @repository : {{@type.id}},
          @rewind_proc : Proc(Mongo::Cursor)
        )
        end

        def next
          if next_bson = @mongo_cursor.next
            @repository.from_bson(next_bson)
          else
            stop
          end
        end

        def rewind
          @mongo_cursor.finalize
          @mongo_cursor = @rewind_proc.call
        end
      end

      def to_bson(entity : EntityClass) : BSON
        proc = to_bson_macro({{@type.superclass.type_vars.first}})
        proc.call(entity)
      end

      macro to_bson_macro(klass_path)
        {% verbatim do %}
          ->(entity : {{klass_path}}) {
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
                        %bson["{{field_name}}"] = %proc.call(entity.{{ivar.name}}.not_nil!)
                      end
                      {% transformed_value = true %}
                    {% end %}
                    {% if type.name =~ /Array/ %}
                      {% item_type = type.type_vars.first %}
                      {% doc_ann = item_type.annotation(Document) %}
                      {% has_field = item_type.instance_vars.any? { |v| v.annotation(Field) } %}
                      unless entity.{{ivar.name}}.nil?
                        {% if doc_ann || has_field %}
                          %bson.append_array("{{field_name}}") do |appender, child|
                            entity.{{ivar.name}}.not_nil!.each do |v|
                              %proc = to_bson_macro({{item_type}})
                              appender << %proc.call(v)
                            end
                          end
                        {% else %}
                          %bson.append_array("{{field_name}}") do |appender, child|
                            entity.{{ivar.name}}.not_nil!.each do |v|
                              appender << v
                            end
                          end
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
        proc = from_bson_macro("", {{@type.superclass.type_vars.first}}, {{main_entity_type}})
        proc.call(bson)
      end

      macro from_bson_macro(ns_prefix, klass_path, main_klass_path)
        {% verbatim do %}
          ->(bson : BSON) {
            {% ns = "#{ns_prefix.id}#{klass_path.names.join("_").downcase.id}_".id %}
            {% klass = klass_path.resolve %}
            {% main_klass = main_klass_path.resolve %}
            {% type_map = {} of MacroId => TypeNode %}

            {% for ivar in klass.instance_vars %}
              {% id_ann = ivar.annotation(Id) %}
              {% if id_ann %}
                {{ns}}id_default = {{ivar.default_value || "nil".id}}
                {% if ivar.type.union_types.any? { |t| t.name =~ /^Nil$/ } %}
                  {{ns}}id_default ||= BSON::ObjectId.new
                {% end %}
                begin
                  {{ns}}{{ivar.name}}_value = bson["_id"].as(BSON::ObjectId)
                rescue IndexError
                  {{ns}}{{ivar.name}}_value = nil
                  if required_nil_defaults
                    {{ns}}{{ivar.name}}_default = BSON::ObjectId.new
                  end
                end
              {% end %}

              {% field_ann = ivar.annotation(Field) %}
              {% if field_ann %}
                {% type_map[ivar.name] = ivar.type %}
                {% field_name = field_ann[:name] ? field_ann[:name].id : ivar.name %}
                begin
                  {{ns}}{{ivar.name}}_default = {{ivar.default_value || "nil".id}}

                  {% unless ivar.type.union_types.any? { |t| t.name =~ /^Nil$/ } %}
                    if required_nil_defaults
                      {% if ivar.type.union_types.any? { |t| t.name =~ /^String$/ } %}
                        {{ns}}{{ivar.name}}_default = ""
                      {% elsif ivar.type.union_types.any? { |t| t.name =~ /^Int/ } %}
                        {{ns}}{{ivar.name}}_default = 0
                      {% elsif ivar.type.union_types.any? { |t| t.name =~ /^Float/ } %}
                        {{ns}}{{ivar.name}}_default = 0.0
                      {% elsif ivar.type.union_types.any? { |t| t.name =~ /^Bool$/ } %}
                        {{ns}}{{ivar.name}}_default = false
                      {% elsif ivar.type.union_types.any? { |t| t.name =~ /^Time$/ } %}
                        {{ns}}{{ivar.name}}_default = Time.unix(0)
                      {% elsif ivar.type.union_types.any? { |t| t.name =~ /^Array/ } %}
                        {{ns}}{{ivar.name}}_default = [] of {{ivar.type.union_types.first.type_vars.first.name}}

                      {% end %}
                    end
                  {% end %}

                  {% transformed_value = false %}
                  {% if ivar.type.is_a?(TypeNode) %}
                    {% for type in ivar.type.union_types %}
                      {% doc_ann = type.annotation(Document) %}
                      {% if doc_ann %}
                        %proc = from_bson_macro("{{field_name}}_", {{type}}, {{main_klass_path}})
                        {{ns}}{{ivar.name}}_value = %proc.call(bson["{{field_name}}"].as(BSON))
                        {% transformed_value = true %}
                      {% end %}
                      {% if type.name =~ /Array/ %}
                        {% union_item_type = type.type_vars.join("|").id %}
                        {% first_item_type = type.type_vars.first %}
                        {% doc_ann = first_item_type.annotation(Document) %}
                        {% has_field = first_item_type.instance_vars.any? { |v| v.annotation(Field) } %}
                        %value = [] of {{first_item_type.name}}
                        %bson_array = bson["{{field_name}}"]
                        if %bson_array.is_a?(BSON)
                          %bson_array.each do |v|
                            {% if doc_ann || has_field %}
                              %proc = from_bson_macro("{{ivar.name}}_", {{first_item_type}}, {{main_klass_path}})
                              %value << %proc.call(v.value.as(BSON))
                            {% else %}
                              %value << v.value.as({{union_item_type}})
                            {% end %}
                          end
                        end
                        {{ns}}{{ivar.name}}_value = %value
                        {% transformed_value = true %}
                      {% end %}
                    {% end %}
                    {% unless transformed_value %}
                      {% enum_type = ivar.type.union_types.find { |t| t.ancestors.any? { |t2| t2.name =~ /^Enum$/ } } %}
                      {% if enum_type %}
                        {% unless ivar.type.union_types.any? { |t| t.name =~ /^Nil$/ } %}
                          {{ns}}{{ivar.name}}_default = {{enum_type}}.new(0)
                        {% end %}
                        unless bson["{{field_name}}"].nil?
                          {{ns}}{{ivar.name}}_value = {{enum_type}}.new(bson["{{field_name}}"].as(Int32))
                        end
                      {% else %}
                        {{ns}}{{ivar.name}}_value = bson["{{field_name}}"].as({{ ivar.type.id }})
                      {% end %}
                    {% end %}
                  {% end %}
                rescue IndexError
                  {{ns}}{{ivar.name}}_value = {{ns}}{{ivar.name}}_default
                end
              {% end %}
            {% end %}

            {% init_arg_names = [] of MacroId %}
            {% init_arg_fields = [] of StringLiteral %}
            {% for imethod in klass.methods %}
              {% if imethod.annotation(Initialize) %}
                {% for arg in imethod.args %}
                  {% suffix = "" %}
                  {% unless type_map[arg.name].union_types.any? { |t| t.name =~ /^Nil$/ } %}
                    {% suffix = ".not_nil!" %}
                  {% end %}
                  {% init_arg_field_value = "(#{ns}#{arg.name}_value || #{arg.default_value || "nil".id} || #{ns}#{arg.name}_default)" %}
                  {% init_arg_fields << "#{arg.name.id}: #{init_arg_field_value.id}#{suffix.id}" %}
                  {% init_arg_names << arg.name %}
                  {% unless type_map[arg.name].union_types.any? { |t| t.name =~ /^Nil$/ } %}
                    if ({{init_arg_field_value.id}}).nil?
                      raise Glassy::MongoODM::Exceptions::NoDefaultValue.new("No default value for arg {{arg.name.id}}")
                    end
                  {% end %}
                {% end %}
              {% end %}
            {% end %}

            {% if klass == main_klass %}
              %entity = CurrentEntityProxy.new({{ init_arg_fields.join(", ").id }})
            {% else %}
              %entity = {{klass.id}}.new({{ init_arg_fields.join(", ").id }})
            {% end %}

            {% for ivar in klass.instance_vars %}
              {% if ivar.annotation(Id) || ivar.annotation(Field) %}
                {% unless init_arg_names.includes?(ivar.name) %}
                  {% suffix = "" %}
                  {% unless ivar.type.union_types.any? { |t| t.name =~ /^Nil$/ } %}
                    {% suffix = ".not_nil!" %}
                    if ({{ns}}{{ivar.name}}_value || {{ns}}{{ivar.name}}_default).nil?
                      raise Glassy::MongoODM::Exceptions::NoDefaultValue.new("No default value for arg {{ivar.name.id}}")
                    end
                  {% end %}
                  %entity.{{ivar.name}} = ({{ns}}{{ivar.name}}_value || {{ns}}{{ivar.name}}_default){{suffix.id}}
                {% end %}
              {% end %}
            {% end %}

            if %entity.is_a?(CurrentEntityProxy)
              %entity.odm_original_bson = to_bson(%entity)
            end

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

      def get_primary_key(entity : EntityClass) : BSON::ObjectId?
        get_primary_key_macro
      end

      def set_primary_key(entity : EntityClass, id : BSON::ObjectId)
        set_primary_key_macro
      end

      macro get_primary_key_macro
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

      macro set_primary_key_macro
        {% verbatim do %}
          pk = nil
          has_pk_field = false
          {% klass = @type.superclass.type_vars.first.resolve %}
          {% for ivar in klass.instance_vars %}
            {% id_ann = ivar.annotation(Id) %}
            {% if id_ann %}
              entity.{{ivar.name}} = id
            {% end %}
          {% end %}
        {% end %}
      end

      def database_name : String
        @connection.default_database
      end
    end
  end
end
