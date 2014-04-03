# -*- coding: utf-8 -*-
require 'fileutils'
module HuiPluginPool
  class Fileslist < GenericHuiPlugin
    PhysicalLinkDepth = 4

    class NoUploadedFileError < RuntimeError; end
    class NoSuchFolderError < RuntimeError; end

    def admin(params)
      if params[:current_folder_id] then
        current_folder_id = params[:current_folder_id] 
        current_folder = get_file_by_id(current_folder_id)
        children_ids = current_folder["children_ids"] || []
        children = get_table("files").find({"_id" => {"$in" => children_ids}})

        {:file => "views/admin.slim",
          :locals => {:current_folder_id => current_folder_id,
            :current_folder => current_folder,
            :children => children}}      
      else 
        {:redirect_to => "admin?current_folder_id=#{get_root_folder_id}"}
      end
    end

    def thumbs(params)
      current_folder_id = params[:current_folder_id] 
      current_folder = get_file_by_id(current_folder_id)
      children_ids = current_folder["children_ids"] || []
      children = get_table("files").find({"_id" => {"$in" => children_ids}}).to_a

      {:file => "views/thumbs.slim",
        :locals => {:current_folder_id => current_folder_id,
          :current_folder => current_folder,
          :children => children}}
    end

    def new_folder(params)
      current_folder_id = params[:current_folder_id] 
      current_folder = get_file_by_id(current_folder_id)

      {:file => "views/new_folder.slim",
        :locals => {:current_folder_id => current_folder_id,
          :current_folder => current_folder}}
    end

    def create_folder(params)
      name = if params[:name].blank? then 
               get_default_name
             else 
               params[:name]
             end

      current_folder_id = params[:current_folder_id]
      new_folder_id = get_table("files").insert(
        "name" => name,
        "parent_id" => BSON::ObjectId(current_folder_id),
        "is_folder" => true,
        "create_at" => Time.now)
      get_table("files").update(
        {"_id" => BSON::ObjectId(current_folder_id)},
        {"$addToSet" => {"children_ids" => new_folder_id}})
      {:redirect_to => "admin?current_folder_id=#{current_folder_id}"}
    end

    def new_file(params)
      current_folder_id = params[:current_folder_id] 
      current_folder = get_file_by_id(current_folder_id)

      {:file => "views/new_file.slim",
        :locals => {:current_folder_id => current_folder_id,
          :current_folder => current_folder}}
    end

    def create_file(params)
      begin
        create_file_with_upload(
          params[:current_folder_id], params[:name], params[:file])
        {:redirect_to => "admin?current_folder_id=#{params[:current_folder_id]}"}
      rescue NoUploadedFileError
        {:text => "error: no uploaded file"}
      rescue NoSuchFolderError
        {:text => "error: current folder does not exist"}
      end
    end

    def new_link_file(params)
      current_folder_id = params[:current_folder_id] 
      current_folder = get_file_by_id(current_folder_id)

      {:file => "views/new_link_file.slim",
        :locals => {:current_folder_id => current_folder_id,
          :current_folder => current_folder}}
    end

    def create_link_file(params)
      current_folder_id = params[:current_folder_id] 
      current_folder = get_file_by_id(current_folder_id)
      link = params[:link]
      if link.blank? then
        {:text => "link should not be empty"}
      else
        name = if params[:name].blank? then
                 File.basename(link, ".*")
               else
                 params[:name]
               end

        insert_file_record(name, link, current_folder_id)
        {:redirect_to => "admin?current_folder_id=#{current_folder_id}"}
      end
    end

    def edit_name(params)
      current_folder_id = params[:current_folder_id] 
      f_id = params[:f_id]
      f = get_file_by_id(f_id)

      {:file => "views/edit_name.slim",
        :locals => {:current_folder_id => current_folder_id,
          :f => f}}
    end

    def update_name(params)
      name = if params[:new_name].blank? then
               get_default_name
             else 
               params[:new_name]
             end

      current_folder_id = params[:current_folder_id]
      f_id = params[:f_id]

      get_table("files").update(
        {"_id" => BSON::ObjectId(f_id)},
        {"$set" => {"name" => name}})
      {:redirect_to => "admin?current_folder_id=#{current_folder_id}"}
    end

    # 参数：如果f_id对应一个目录，将会给出这个目录的名字、_id和目录下的
    # 所有文件、子目录的id、名字和链接。如果f_id对应一个文件，则会给出
    # 这个文件的id、名字和链接。f_id可以为空，这时会默认为根目录。如果
    # 链接以http://开头，表示是外部链接，否则表示是内部链接。内部链接需
    # 要在前面加上会务平台服务器的地址才能访问。
    def api_list(params)
      f_id = if params[:f_id].blank? then
               get_root_folder_id
             else
               params[:f_id]
             end
      f = get_file_by_id(f_id)

      if f.nil? then
        {:json => {:error => "wrong f_id"}}
      elsif f["is_folder"] then
        children_ids = f["children_ids"] || []
        children = get_table("files").find({"_id" => {"$in" => children_ids}})
        children_hashes = children.map do |ch|
          ch_data = {:_id => ch["_id"].to_s, :name => ch["name"]}
          if ch["is_folder"] then
            ch_data[:is_folder] = true
          else
            ch_data[:link] = ch["physical_link"] unless ch["is_folder"]
          end
          ch_data
        end
        {:json => {
            :_id => f["_id"].to_s,
            :name => f["name"],
            :is_folder => true,
            :children => children_hashes}}
      else
        {:json => {
            :_id => f["_id"].to_s,
            :name => f["name"],
            :link => f["physical_link"]}}
      end
    end

    # 接受四个参数：folder_id、user_id、name和file。其中folder_id是要上
    # 传到的目录的id，name表示在系统中所取的文件名，file则应该是一段
    # multipart的数据，表示文件内容。成功上传时返回{"ok": true}。
    def api_upload(params)
      begin
        user = get_friend("userslist").get_user_by_id(params[:user_id])
        username = if user then user["name"] else "" end

        create_file_with_upload(
          params[:folder_id], params[:name], params[:file], username)
        {:json => {:ok => true}}
      rescue NoUploadedFileError
        {:json => {:error => "no uploaded file"}}
      rescue NoSuchFolderError
        {:json => {:error => "wrong folder_id"}}
      end      
    end

    private

    def get_root_folder_id
      root = get_table("files").
        find_one("name" => "/", "parent_id" => nil, "is_folder" => true)

      if root then
        root["_id"].to_s
      else
        get_table("files").
          insert("name" => "/", "parent_id" => nil, "is_folder" => true)
        get_root_folder_id
      end
    end

    def get_file_by_id(_id)
      begin
        if _id.is_a? String then
          _id = BSON::ObjectId(_id)
        end
        get_table("files").find_one("_id" => _id)
      rescue BSON::InvalidObjectId
        nil
      end
    end

    def get_random_relative_physical_link(extname)
      dirs = (0...PhysicalLinkDepth).map { SecureRandom.hex(1) }
      filename = SecureRandom.hex(16) + extname
      ["/system", *dirs, filename].join("/")
    end

    def insert_file_record(name, link, current_folder_id, uploader_name="")
      new_file_id = get_table("files").insert(
        "name" => name,
        "physical_link" => link,
        "parent_id" => BSON::ObjectId(current_folder_id),
        "creator" => uploader_name,
        "is_folder" => false,
        "create_at" => Time.now)
      get_table("files").update(
        {"_id" => BSON::ObjectId(current_folder_id)},
        {"$addToSet" => {"children_ids" => new_file_id}})
    end

    def get_default_name
      "未命名#{Time.now.getlocal.strftime('%Y%m%d%H%M%S')}"
    end

    def create_file_with_upload(folder_id, name, uploaded_file, uploader_name="")
      folder = get_file_by_id(folder_id)
      
      raise NoUploadedFileError if uploaded_file.nil? 
      raise NoSuchFolderError if folder.nil?
        
      original_filename = uploaded_file.original_filename
      tempfile_path = uploaded_file.tempfile.path
      final_name = if name.blank? then
                     File.basename(original_filename, ".*")
                   else
                     name
                   end
      extname = File.extname(original_filename)

      begin  # caution! this is an "end while" pattern
        physical_link = get_random_relative_physical_link(extname)
        absolute_physical_path = File.join(Rails.root, "public", physical_link)
      end while File.exists?(absolute_physical_path)

      FileUtils.mkdir_p(File.dirname(absolute_physical_path))
      FileUtils.mv(tempfile_path, absolute_physical_path)
      insert_file_record(final_name, physical_link, folder_id, uploader_name)
    end
  end
end
