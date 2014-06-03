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

      def render_value(field, value)
        case field["type"]
        when "string" then value
        when "number" then value
        when "boolean" then if value then "是" else "否" end
        when "datetime" then value.getlocal.strftime("%Y年%m月%d日 %H:%M")
        else "查看"
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
        else link_to "查找", "javascript:void(0)"
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

      data = get_table("dynamic_db").find("_kind" => class_code_name)

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

        {:file => "views/global_edit.slim",
          :locals => {:db_class => db_class,
            :row => row,
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

    action :error, :get do |params|
      {:file => "views/error.slim",
        :locals => {:message => params[:message]}}
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
  end
end
