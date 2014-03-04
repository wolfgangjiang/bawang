# -*- coding: utf-8 -*-
module HuiPluginPool
  class Userslist < GenericHuiPlugin
    Columns = ["name", "national_id", "email", "mobile", "company", "city",]
    HumanColumns = {"reject" => "舍弃",
      "name" => "姓名",
      "national_id" => "身份证号",
      "email" => "电子邮箱",
      "mobile" => "手机号",
      "company" => "工作单位",
      "city" => "城市"}

    def admin(params)
      users = get_table("users").find
      {:file => "views/admin.slim",
        :locals => {
          :users => users,
          :columns => Columns,
          :human_columns => HumanColumns}}
    end

    def clear(params)
      get_table("users").remove
      {:redirect_to => "admin"}
    end

    def import_select_file(params)
      {:file => "views/import_select_file.slim"}
    end

    def import_upload_file(params)
      # we only use one single temp for one event, if multiple uploads
      # occurs before old upload is commited, old upload is
      # overwritten
      csv_content = File.read(params[:file].tempfile)

      get_table("temp").update(
        {:name => "csv_content"},  
        {"$set" => {:csv_content => csv_content}},
        {:upsert => true})
      {:redirect_to => "import_arrange_columns"}
    end

    def import_arrange_columns(params)
      require 'csv'
      csv_content = get_table("temp").
        find_one(:name => "csv_content")["csv_content"]
      data = CSV.parse(csv_content)
      {:file => "views/import_arrange_columns.slim",
        :locals => {
          :data => data,
          :width => data[0].length,
          :column_options => HumanColumns.invert}}
    end

    def import_determine_columns(params)
      csv_content = get_table("temp").
        find_one(:name => "csv_content")["csv_content"]
      get_table("preview_users").remove
      data = CSV.parse(csv_content)
      columns = params[:columns]
      data.each do |row|
        document = {:password => "initial_password"}
        columns.zip(row).each do |col, value|
          document[col] = value unless col == "reject"
        end
        get_table("preview_users").insert(document)
      end
      {:redirect_to => "import_preview"}
    end

    def import_preview(params)
      preview_users = get_table("preview_users").find
      {:file => "views/import_preview.slim",
        :locals => {
          :preview_users => preview_users,
          :columns => Columns,
          :human_columns => HumanColumns
        }}
    end

    def import_commit(params)
      get_table("preview_users").find.each do |u|
        u.delete("_id")
        get_table("users").insert(u)
        p get_table("users").find.to_a
      end
      get_table("preview_users").remove
      p get_table("users").find.to_a
      {:redirect_to => "admin"}
    end
  end
end
