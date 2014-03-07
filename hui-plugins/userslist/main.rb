# -*- coding: utf-8 -*-
module HuiPluginPool
  class Userslist < GenericHuiPlugin
    class AsFriend < self
      def get_user_by_id(_id)
        if _id.is_a? String then
          begin
            _id = BSON::ObjectId(_id)
          rescue BSON::InvalidObjectId
            _id = nil
          end
        end

        get_table("users").find_one(:_id => _id)
      end
    end

    SyncPivots = ["national_id", "mobile", "email"]
    class PasswordBlankError < RuntimeError; end

    def admin(params)
      users = get_table("users").find.sort({"_id" => 1})
      users_count = get_table("users").find.count

      usersync_task_id = read_temp("usersync_task_id")
      if usersync_task_id then
        usersync_task_status = AsyncTask.get_status(usersync_task_id)
        clear_temp("usersync_task_id") if usersync_task_status["finished"]
      else
        usersync_task_status = nil
      end

      {:file => "views/admin.slim",
        :locals => {
          :users => users,
          :users_count => users_count,
          :columns => HuiMain::UserColumns,
          :human_columns => HuiMain::HumanUserColumns,
          :usersync_task_status => usersync_task_status}}
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

      write_temp("csv_content", csv_content)
      {:redirect_to => "import_arrange_columns"}
    end

    def import_arrange_columns(params)
      require 'csv'
      csv_content = read_temp("csv_content")
      data = CSV.parse(csv_content)
      {:file => "views/import_arrange_columns.slim",
        :locals => {
          :data => data,
          :width => data[0].length,
          :column_options => HuiMain::HumanUserColumns.invert}}
    end

    def import_determine_columns(params)
      csv_content = read_temp("csv_content")
      get_table("preview_users").remove
      data = CSV.parse(csv_content)
      columns = params[:columns]
      data.each do |row|
        document = {:password => params["initial_password"]}
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
          :columns => HuiMain::UserColumns,
          :human_columns => HuiMain::HumanUserColumns
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

    def sync_one(params)
      user = get_friend("userslist").get_user_by_id(params[:user_id])

      if user then
        sync_one_user(user, get_event_title)
      end #else do nothing

      {:redirect_to => "admin"}
    end

    def edit(params)
      user = get_friend("userslist").get_user_by_id(params[:user_id])
      raise "no such user" unless user

      {:file => "views/edit.slim",
        :locals => {
          :user => user,
          :columns => HuiMain::UserColumns,
          :human_columns => HuiMain::HumanUserColumns}}            
    end

    def update(params)
      generic_update(params)
      {:redirect_to => "admin"}
    end

    def edit_password(params)
      user = get_friend("userslist").get_user_by_id(params[:user_id])
      raise "no such user" unless user

      {:file => "views/edit_password.slim",
        :locals => {
          :user => user,
          :columns => HuiMain::UserColumns,
          :human_columns => HuiMain::HumanUserColumns}}
    end

    def update_password(params)
      user = get_friend("userslist").get_user_by_id(params[:user_id])
      raise "no such user" unless user
      raise "password should not be empty" if params[:password].blank?

      # get_table("users").update({:_id => user["_id"]},
      #   {"$set" => {:password => params[:password]}})
      # sync_password_to_main_user_table(user, params[:password])
      generic_update_password(user, params[:password])
      {:redirect_to => "admin"}
    end

    def destroy(params)
      user = get_friend("userslist").get_user_by_id(params[:user_id])

      if user then
        get_table("users").remove({:_id => user["_id"]})
      end # else do not raise "no such user" error
      {:redirect_to => "admin"}
    end

    def sync_all(params)
      users_count = get_table("users").find.count
      users = get_table("users").find.sort({"_id" => 1})
      event_title = get_event_title

      task_id = AsyncTask.start do |task|
        task.set_total(users_count)
        progress = 0
        users.each do |u|
          sync_one_user(u, event_title)
          progress += 1
          task.set_progress(progress) if progress % 13 == 0 or progress < 13
        end
        task.finish_with(nil)
      end

      write_temp("usersync_task_id", task_id)
      {:redirect_to => "admin"}
    end

    def new(params)
      {:file => "views/new.slim",
        :locals => {
          :columns => HuiMain::UserColumns,
          :human_columns => HuiMain::HumanUserColumns}}            
    end

    def create(params)
      generic_create(params)
      {:redirect_to => "admin"}      
    end

    # 登录。格式：{"login_key_name": "mobile",
    # "login_name":"13811110001", "password":"xxxx"}，共三个有效的key。
    # login_key_name可以是mobile、email或national_id。正确登录时返回
    # user_id。
    def api_login(params)
      user = authenticate(
        params[:login_key_name], params[:login_name], params[:password])
      if user then
        {:json => {:user_id => user["_id"].to_s}}
      else
        {:json => {:user_id => nil, :info => "login failed"}}
      end
    end

    # 修改用户属性，格式：{"user_id": "xxxx", "name": "xxx", ...}
    # 有效的key是user_id和UserColumns中的key，password字段会被无视。
    # update_password api才能修改密码。正常修改后会返回{ok:true}
    def api_update(params)
      generic_update(params)
      {:json => {:ok => true}}
    end

    # 创建用户，格式：{"password": "xxx", "name": "xxx", ...} 有效的
    # key是password和UserColumns中的key。密码不能为null或空字符串，否则
    # 会报错。正常创建后会返回{ok:true, user_id:"xxxx"}
    def api_create(params)
      begin
        user_id = generic_create(params)
        {:json => {:ok => true, :user_id => user_id.to_s}}
      rescue PasswordBlankError
        {:json => {:error => "password should not be blank"}}
      end
    end

    # 修改密码。格式：{"user_id": "xxxx", "old_password": "xxxx",
    # "new_password": "xxxx"}。共三个有效的key。old_password必须是当前
    # 有效的密码，new_password不能为null或空字符串，否则报错。正常修改
    # 后会返回{ok:true}
    def api_update_password(params)
      user = get_friend("userslist").get_user_by_id(params[:user_id])
      raise "no such user" unless user

      old_password = params[:old_password]
      pivot = get_sync_pivot(user)
      auth_user = authenticate(pivot, user[pivot], old_password)
      if auth_user then
        begin
          generic_update_password(user, params[:new_password])
          {:json => {:ok => true}}
        rescue PasswordBlankError
          {:json => {:error => "password should not be blank"}}
        end
      else
        {:json => {:error => "old password incorrect"}}
      end
    end

    private

    def authenticate(login_key_name, login_name, password)
      get_table("users").find_one(
        login_key_name => login_name, :password => password)
    end

    def sync_one_user(user, event_title)
      # only one pivot is chosen for sync
      sync_able_pivot = get_sync_pivot(user)

      updated_user = user.except("_id")
      if sync_able_pivot then # get info from main_user
        main_user =
          HuiMain.users.find_one(sync_able_pivot => user[sync_able_pivot])
        # password is always overwriten
        updated_user["password"] = main_user["password"]
        HuiMain::UserColumns.each do |col|
          # never overwrite property value
          updated_user[col] = main_user[col] if updated_user[col].blank?
        end
        updated_user["hui_sync_time"] = Time.now
        updated_user["hui_sync_status"] = "从主表同步了密码和基本属性"
        get_table("users").update({:_id => user["_id"]}, updated_user)

        updated_main_user = main_user.except("_id")
        HuiMain::UserColumns.each do |col|
          # also never overwrite property value
          updated_main_user[col] = user[col] if updated_main_user[col].blank?
        end
        updated_main_user["hui_sync_time"] = Time.now
        updated_main_user["hui_sync_source"] = event_title
        HuiMain.users.update({:_id => main_user["_id"]},
          {"$set" => updated_main_user})
      elsif SyncPivots.all? {|pivot| user[pivot].blank?} # create a new main_user 
        # do not sync if all pivot properties are missing
        get_table("users").update({:_id => user["_id"]},
          {"$set" => {
              "hui_sync_time" => Time.now,
              "hui_sync_status" => "发现缺少可标识身份的属性而无法同步"}})
      else
        # only UserColumns and password are synchronized, custom properties
        # in particular event are not synchronized into main user table
        get_table("users").update({:_id => user["_id"]},
          {"$set" => {
              "hui_sync_time" => Time.now,
              "hui_sync_status" => "作为新用户同步到了主表"}})

        updated_main_user = updated_user.slice("password", *HuiMain::UserColumns)
        updated_main_user["hui_sync_time"] = Time.now
        updated_main_user["hui_sync_source"] = event_title
        HuiMain.users.insert(updated_main_user)
      end
    end

    def sync_password_to_main_user_table(user, new_password)
      sync_able_pivot = get_sync_pivot(user)

      if sync_able_pivot then # get info from main_user
        main_user =
          HuiMain.users.find_one(sync_able_pivot => user[sync_able_pivot])
        HuiMain.users.update({:_id => main_user["_id"]},
          {"$set" => {:password => new_password}})
      end # else do nothing
    end

    def get_sync_pivot(user)
      SyncPivots.find do |pivot|
        # it is not a sync_able_pivot if user[pivot] is nil or missing or ""
        (not user[pivot].blank?) and HuiMain.users.find_one(pivot => user[pivot])
      end
    end

    def write_temp(name, value)
      name_s = name.to_s
      get_table("temp").update(
        {:name => name_s},
        {"$set" => {name_s => value}},
        {:upsert => true})
    end

    def read_temp(name)
      name_s = name.to_s
      rec = get_table("temp").find_one(:name => name_s)
      if rec then
        rec[name_s]
      else
        nil
      end
    end

    def clear_temp(name)
      name_s = name.to_s
      get_table("temp").remove(:name => name_s)
    end

    def generic_update(params)
      user = get_friend("userslist").get_user_by_id(params[:user_id])
      raise "no such user" unless user

      data = params.slice(*HuiMain::UserColumns)
      get_table("users").update({:_id => user["_id"]}, {"$set" => data})
    end

    def generic_create(params)
      raise PasswordBlankError if params[:password].blank?

      data = params.slice(params[:password], *HuiMain::UserColumns)
      get_table("users").insert(data)
    end

    def generic_update_password(user, password)
      raise PasswordBlankError if password.blank?
      get_table("users").update({:_id => user["_id"]},
        {"$set" => {:password => password}})
      sync_password_to_main_user_table(user, password)
    end
  end
end
