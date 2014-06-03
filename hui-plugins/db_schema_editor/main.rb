# -*- coding: utf-8 -*-
module HuiPluginPool
  class DbSchemaEditor < GenericHuiPlugin
    class AsFriend < GenericHuiPlugin::AsFriend
      def get_schema
        JSON.parse(@main_object.send(:safe_get_schema))
      end
    end

    HumanTypeNames = {
      "string" => "字符串",
      "number" => "数值",
      "datetime" => "日期时间",
      "boolean" => "是非",
      "one-to-one" => "一对一",
      "one-to-many" => "一对多",
      "many-to-one" => "多对一",
      "many-to-many" => "多对多"
    } # 在添加新类型时请注意与edit的db_schema_editor.js中的
      # FIELD_TYPE_CANDIDATES同步

    action :admin, :get do |params|
      schema = JSON.parse(safe_get_schema)
      fill_in_reverse_human_name(schema)

      {:file => "views/admin.slim",
        :locals => {:schema => schema,
          :human_type_names => HumanTypeNames}}
    end

    action :clear, :post do |params|
      if Rails.env != "production" then
        clear_var("schema")
      else
        raise "cannot clear it in production mode"
      end

      {:redirect_to => "admin"}
    end

    action :edit, :get do |params|
      schema = safe_get_schema

      {:file => "views/edit.slim",
        :locals => {:schema => schema,
          :human_type_names => JSON.generate(HumanTypeNames)}}
    end

    action :save, :post do |params|
      write_var("schema", params[:data_to_be_saved])
      {:redirect_to => "edit"}
    end

    private

    def safe_get_schema
      schema = read_var("schema")
      if schema.nil? or schema == "[]" then
        "[]"
      else
        schema
      end
    end

    def fill_in_reverse_human_name(schema)
      schema.each do |cl|
        cl["fields"].each do |f|
          if /-to-/ =~ f["type"] then
            reverse_class = schema.find {|x| x["code_name"] == f["reverse_class"]}
            if reverse_class then
              f["reverse_class_human_name"] = reverse_class["human_name"] 
              reverse_field = reverse_class["fields"].find {|x| 
                x["code_name"] == f["reverse_field"]}
              if reverse_field then
                f["reverse_field_human_name"] = reverse_field["human_name"]
              else
                f["reverse_field_human_name"] = "（未指定）"
              end
            else
              f["reverse_class_human_name"] = "（未指定）"
              f["reverse_field_human_name"] = "（未指定）"
            end
          end
        end
      end
    end
  end
end
