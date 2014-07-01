# -*- coding: utf-8 -*-
module HuiPluginPool
  class DbBrowser < GenericHuiPlugin
    class AsFriend < GenericHuiPlugin::AsFriend
    end

    class ReprFieldEmptyError < RuntimeError; end

    class FieldHelper
      include ActionView::Helpers::FormTagHelper
      include ActionView::Helpers::FormOptionsHelper
      include ActionView::Helpers::UrlHelper

      def render_value(field, row)
        value = row[field["code_name"]]
        case field["type"]
        when "string" then value
        when "number" then value
        when "boolean" then if value then "是" else "否" end
        when "datetime" then value.getlocal.strftime("%Y年%m月%d日 %H:%M")
        when /-to-one/ then row[field["code_name"] + "_repr"]
        when /-to-many/ then "#{row[field['code_name'] + '_count']}个"
        else "不支持的类型"
        end
      end

      def render_input(field)
        code_name = field["code_name"]
        case field["type"]
        when "string" then text_field_tag code_name
        when "number" then number_field_tag code_name, 0
        when "boolean" then select_tag code_name, options_for_select([["是", "true"], ["否", "false"]])
        when "datetime" then datetime_local_field_tag code_name
        else link_to "查找", "javascript:void(0)"
        end
      end

      def render_input_with_value(field, value)
        code_name = field["code_name"]
        case field["type"]
        when "string" then text_field_tag code_name, value
        when "number" then number_field_tag code_name, value
        when "boolean" then select_tag code_name, options_for_select([["是", "true"], ["否", "false"]], :selected => value)
        when "datetime" then datetime_local_field_tag code_name, value.getlocal.strftime("%Y-%m-%dT%H:%M")
        else 
          "<span>" + 
            link_to("查找", "javascript:void(0)", :class => "relation-ajax-menu", :field_code_name => code_name) +
            hidden_field_tag(code_name, JSON.generate(value)) +
            "</span>"
        end
      end
    end

    action :admin, :get do |params|
      schema = get_friend("db_schema_editor").get_schema

      {:file => "views/admin.slim",
        :locals => {:schema => schema}}
    end

    action :global_index, :get do |params|
      class_code_name = params[:class_code_name]
      schema = get_friend("db_schema_editor").get_schema
      db_class = schema.find {|x| x["code_name"] == class_code_name}

      data = get_table("dynamic_db").find("_kind" => class_code_name).to_a

      batch_blow_relations(data, db_class, schema)

      {:file => "views/global_index.slim",
        :locals => {:db_class => db_class,
          :data => data,
          :field_helper => FieldHelper.new}}
    end

    action :global_new, :get do |params|
      class_code_name = params[:class_code_name]
      schema = get_friend("db_schema_editor").get_schema
      db_class = schema.find {|x| x["code_name"] == class_code_name}

      {:file => "views/global_new.slim",
        :locals => {:db_class => db_class,
          :field_helper => FieldHelper.new}}
    end

    action :global_create, :post do |params|
      class_code_name = params[:class_code_name]
      schema = get_friend("db_schema_editor").get_schema
      db_class = schema.find {|x| x["code_name"] == class_code_name}

      begin
        record = prepare_data(params, db_class)
        get_table("dynamic_db").insert(record)
        {:redirect_to => "global_index?class_code_name=#{class_code_name}"}
      rescue ReprFieldEmptyError
        {:redirect_to => "error?message=Repr_field_should_not_be_empty"}
      end
    end

    action :global_edit, :get do |params|
      row = get_table("dynamic_db").find_one("_id" => ensure_bson_id(params[:id]))

      if row then
        class_code_name = row["_kind"]
        schema = get_friend("db_schema_editor").get_schema
        db_class = schema.find {|x| x["code_name"] == class_code_name}
        db_ajax_data = {
          :_id => row["_id"].to_s,
          :class_code_name => class_code_name,
          :event_id => @event_id
        }

        {:file => "views/global_edit.slim",
          :locals => {:db_class => db_class,
            :row => row,
            :db_ajax_data => db_ajax_data,
            :field_helper => FieldHelper.new}}        
      else
        {:redirect_to => "error?message=unknown_id"}
      end
    end

    action :global_update, :post do |params|
      row = get_table("dynamic_db").find_one("_id" => ensure_bson_id(params[:id]))

      if row then
        begin
          class_code_name = row["_kind"]
          schema = get_friend("db_schema_editor").get_schema
          db_class = schema.find {|x| x["code_name"] == class_code_name}

          record = prepare_data(params, db_class)
          get_table("dynamic_db").update(
            {"_id" => ensure_bson_id(params[:id])},
            {"$set" => record})
          {:redirect_to => "global_index?class_code_name=#{class_code_name}"}
        rescue ReprFieldEmptyError
          {:redirect_to => "error?message=Repr_field_should_not_be_empty"}
        end
      else
        {:redirect_to => "error?message=unknown_id"}
      end
    end

    action :global_show, :get do |params|
      row = get_table("dynamic_db").find_one("_id" => ensure_bson_id(params[:id]))
      
      if row then
        class_code_name = row["_kind"]
        schema = get_friend("db_schema_editor").get_schema
        db_class = schema.find {|x| x["code_name"] == class_code_name}
        db_data = {
          :schema => schema,
          :class_code_name => class_code_name,
          :_id => row["_id"].to_s,
          :row => row
        }

        batch_blow_relations([db_data[:row]], db_class, schema)

        {:file => "views/global_show.slim",
          :locals => {:db_class => db_class,
            :row => row,
            :db_data => db_data,
            :field_helper => FieldHelper.new}}
      else
        {:redirect_to => "error?message=unknown_id"}
      end
    end

    action :error, :get do |params|
      {:file => "views/error.slim",
        :locals => {:message => params[:message]}}
    end

    action :update_relational, :post do |params|
      _id = params[:id]
      bson_id = ensure_bson_id(_id)
      new_related_ids = JSON.parse(params[:value])
      row = get_table("dynamic_db").find_one("_id" => bson_id)
      field_code_name = params[:field_code_name]
      class_code_name = row["_kind"]
      schema = get_friend("db_schema_editor").get_schema
      db_class = schema.find {|x| x["code_name"] == class_code_name}
      field = db_class["fields"].find {|x| x["code_name"] == field_code_name}
      reverse_field_code_name = field["reverse_field"]
      old_related_ids = row[field_code_name]

      reverse_ids_to_add = (new_related_ids - old_related_ids).
        map {|x| ensure_bson_id(x)}
      reverse_ids_to_subtract = (old_related_ids - new_related_ids).
        map {|x| ensure_bson_id(x)}
      
      if field["type"].include? "-to-many" then
        get_table("dynamic_db").update(
          {"_id" => bson_id},
          {"$set" => {field_code_name => new_related_ids}})
      else # "-to-one"
        get_table("dynamic_db").update(
          {"_id" => bson_id},
          {"$set" => {field_code_name => new_related_ids.take(1)}})
      end

      if field["type"].include? "many-to-" then
        get_table("dynamic_db").update(
          {"_id" => {"$in" => reverse_ids_to_add}},
          {"$addToSet" => {reverse_field_code_name => _id}})

        get_table("dynamic_db").update(
          {"_id" => {"$in" => reverse_ids_to_subtract}},
          {"$pull" => {reverse_field_code_name => _id}})
      else # "one-to-"
        get_table("dynamic_db").update(
          {"_id" => {"$in" => reverse_ids_to_add}},
          {"$set" => {reverse_field_code_name => [_id]}}) # we should always set as an array
        
        get_table("dynamic_db").update(
          {"_id" => {"$in" => reverse_ids_to_subtract}},
          {"$set" => {reverse_field_code_name => []}})
      end

      {:redirect_to => "global_show?id=#{_id}"}
    end

    action :ajax_search_relation, :get do |params|
      class_code_name = params[:class_code_name]
      field_code_name = params[:field_code_name]
      schema = get_friend("db_schema_editor").get_schema
      db_class = schema.find {|x| x["code_name"] == class_code_name}
      field = db_class["fields"].find {|x| x["code_name"] == field_code_name}
      reverse_class_code_name = field["reverse_class"]
      reverse_class = schema.find {|x| x["code_name"] == reverse_class_code_name}
      search_result_fields = pick_search_result_fields(reverse_class, 1)
      search_result_data = find_search_result_data(
        params[:search_word], reverse_class, search_result_fields, 10)

      {:json => search_result_data}
    end

    action :ajax_load_relation, :get do |params|
      field_code_name = params[:field_code_name]
      row = get_table("dynamic_db").find_one("_id" => ensure_bson_id(params[:_id]))
      class_code_name = row["_kind"]
      schema = get_friend("db_schema_editor").get_schema
      db_class = schema.find {|x| x["code_name"] == class_code_name}      
      field = db_class["fields"].find {|x| x["code_name"] == field_code_name}
      reverse_class_code_name = field["reverse_class"]
      reverse_class = schema.find {|x| x["code_name"] == reverse_class_code_name}

      ids = (row[field_code_name] || []).map {|x| ensure_bson_id(x)}
      result_fields = pick_search_result_fields(reverse_class, 1)
      related = get_table("dynamic_db").
        find({"_id" => {"$in" => ids}}, :fields => result_fields).to_a
      result_data = format_search_result_data(result_fields, related)

      {:json => result_data}
    end

    private

    def ensure_bson_id(id_s)
      begin
        if id_s.is_a? String then
          BSON::ObjectId.from_string(id_s)
        else
          id_s
        end
      rescue BSON::InvalidObjectId
        nil
      end
    end

    def prepare_data(raw_record, db_class)
      record = db_class["fields"].map do |f|
        raw_value = raw_record[f["code_name"]]

        raise ReprFieldEmptyError if f["is_repr"] and raw_value.blank?

        value = case f["type"]
                when "string" then raw_value.to_s
                when "number" then raw_value.to_f rescue 0
                when "datetime" then Time.parse(raw_value) rescue nil
                when "boolean" then (raw_value == "true")
                else [] # empty relation
                end
        {f["code_name"] => value}
      end.inject(:merge)

      record.merge("_kind" => db_class["code_name"])
    end

    def pick_search_result_fields(db_class, count)
      # For example, we take only 3 fields for each row, thus we get
      # first 3 fields in the class. If they contain a repr field,
      # return them, if they do not contain a repr field, add the repr
      # field to them and return.
      first_count_fields = db_class["fields"].take(count)
      fields = if first_count_fields.any? {|f| f["is_repr"]} then
                 first_count_fields
               else
                 repr_field = db_class["fields"].find {|f| f["is_repr"]}
                 [repr_field] + first_count_fields[0..-2]
               end
      fields.map {|x| x["code_name"]}
    end

    def find_search_result_data(search_word, db_class, fields, limit)
      class_code_name = db_class["code_name"]
      repr_field_code_name =
        db_class["fields"].find {|f| f["is_repr"]}["code_name"]
      raw_data = get_table("dynamic_db").find(
        {"_kind" => class_code_name,
          repr_field_code_name => Regexp.new(search_word)}, 
        :fields => fields).limit(limit).to_a

      format_search_result_data(fields, raw_data)
    end

    def format_search_result_data(fields, raw_data)
      raw_data.map do |row|
        {:id => row["_id"].to_s,
          :cols => fields.map {|f_code_name| row[f_code_name]}}
      end
    end

    def batch_blow_relations(data, db_class, schema)
      db_class["fields"].each do |f|
        if f["type"].include? "-to-one" then
          related_ids = data.map do |row|
            ensure_bson_id(row[f["code_name"]][0])
          end
          related_rows = get_table("dynamic_db").find(
            "_id" => {"$in" => related_ids})
          related_rows_hash = lift_to_hash(related_rows) {|row| row["_id"].to_s}
          reverse_class_code_name = f["reverse_class"]
          reverse_class = schema.find do |cl|
            cl["code_name"] == reverse_class_code_name
          end
          reverse_repr_field = reverse_class["fields"].find do |rf|
            rf["is_repr"]
          end
          reverse_repr = reverse_repr_field["code_name"]
          data.each do |row|
            reverse_row = related_rows_hash[row[f["code_name"]][0]]
            row[f["code_name"] + "_repr"] = if reverse_row then
                                              reverse_row[reverse_repr]
                                            else
                                              "（无）"
                                            end
          end
        elsif f["type"].include? "-to-many" then
          data.each do |row|
            row[f["code_name"] + "_count"] = row[f["code_name"]].length
          end
        end
      end
    end

    def lift_to_hash(data, &get_key)
      hash = {}
      data.each do |row|
        hash[get_key.call(row)] = row
      end
      hash
    end
  end
end
