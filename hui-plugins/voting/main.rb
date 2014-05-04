# -*- coding: utf-8 -*-
module HuiPluginPool
  class Voting < GenericHuiPlugin
    HumanQuestionTypes = {
      "single_choice" => "单选",
      "multiple_choice" => "多选"
    }

    action :admin, :get do |params|
      questions = get_table("voting").
        find("_kind" => "question").
        sort({"is_current" => -1}).to_a

      {:file => "views/admin.slim",
        :locals => {
          :questions => questions,
          :human_question_types => HumanQuestionTypes}}
    end

    action :clear, :post do |params|
      if Rails.env == "production" then
        raise "not permitted to clear data in production mode"
      else
        get_table("voting").remove
      end

      {:redirect_to => "admin"}
    end

    action :set_to_current, :post do |params|
      get_table("voting").update(
        {"_kind" => "question"},
        {"$set" => {"is_current" => false}},
        {:multi => true})
      get_table("voting").update(
        {"_id" => ensure_bson_id(params[:id]),
          "_kind" => "question"},
        {"$set" => {"is_current" => true}})

      {:redirect_to => "admin"}
    end

    action :new_question, :get do |params|
      {:file => "views/new_question.slim",
        :locals => {
          :human_question_types => HumanQuestionTypes}}
    end

    action :create_question, :post do |params|
      sanitized_question_type = 
        if params[:question_type] == "multiple_choice" then
          "multiple_choice"
        else # 不认识的输入一律认为是单选
          "single_choice"
        end

      get_table("voting").insert(
        "_kind" => "question",
        "question_text" => params[:question_text],
        "question_type" => sanitized_question_type,
        "create_at" => Time.now,
        "option_ids" => []);
      {:redirect_to => "admin"}
    end

    action :question, :get do |params|
      q = get_question_by_id(params[:id])
      q["options"] = get_table("voting").find(        
        {"_id" => {"$in" => q["option_ids"]},
          "_kind" => "option"}).to_a

      {:file => "views/question.slim",
        :locals => {:question => q,
          :human_question_types => HumanQuestionTypes}}
    end

    action :edit_question, :get do |params|
      q = get_question_by_id(params[:id])

      {:file => "views/edit_question.slim",
        :locals => {:question => q,
          :human_question_types => HumanQuestionTypes}}      
    end

    action :update_question, :post do |params|
      sanitized_question_type = 
        if params[:question_type] == "multiple_choice" then
          "multiple_choice"
        else # 不认识的输入一律认为是单选
          "single_choice"
        end

      get_table("voting").update(
        {"_id" => ensure_bson_id(params[:id]),
          "_kind" => "question"},
        {"$set" => {"question_text" => params[:question_text],
            "question_type" => sanitized_question_type}})
      {:redirect_to => "question?id=#{params[:id]}"}
    end

    action :remove_question, :post do |params|
      q = get_question_by_id(params[:id])
      get_table("voting").remove(
        {"_kind" => "option",
          "_id" => {"$in" => q["option_ids"]}})
      get_table("voting").remove(
        {"_kind" => "question",
          "_id" => BSON::ObjectId(params[:id])})
      {:redirect_to => "admin"}
    end

    action :new_option, :get do |params|
      {:file => "views/new_option.slim",
        :locals => {:q_id => params[:q_id]}}
    end

    action :create_option, :post do |params|
      q = get_question_by_id(params[:q_id])
      o_id = get_table("voting").insert(
        {"_kind" => "option",
          "option_tag" => params[:option_tag],
          "option_text" => params[:option_text],
          "question_id" => q["_id"],
          "users" => []})
      get_table("voting").update(
        {"_id" => q["_id"]},
        {"$push" => {"option_ids" => o_id}})          

      {:redirect_to => "question?id=#{params[:q_id]}"}
    end

    action :option, :get do |params|
      o = get_table("voting").find_one("_id" => BSON::ObjectId(params[:o_id]))

      {:file => "views/option.slim",
        :locals => {
          :q_id => params[:q_id],
          :option => o}}      
    end

    action :edit_option, :get do |params|
      o = get_table("voting").find_one("_id" => BSON::ObjectId(params[:o_id]))

      {:file => "views/edit_option.slim",
        :locals => {
          :q_id => params[:q_id],
          :option => o}}
    end

    action :update_option, :post do |params|
      get_table("voting").update(
        {"_id" => ensure_bson_id(params[:o_id])},
        {"$set" => {
            "option_tag" => params[:option_tag],
            "option_text" => params[:option_text]}})
      {:redirect_to => "option?q_id=#{params[:q_id]}&o_id=#{params[:o_id]}"}
    end

    action :remove_option, :post do |params|
      get_table("voting").remove({"_id" => ensure_bson_id(params[:o_id])})
      get_table("voting").update(
        {"_id" => ensure_bson_id(params[:q_id])},
        {"$pull" => {"option_ids" => ensure_bson_id(params[:o_id])}})

      {:redirect_to => "question?id=#{params[:q_id]}"}      
    end

    action :get_question_list, :get, :api => true do |params|
      qs = get_table("voting").find("_kind" => "question").map do |q|
        pick_question_info(q)
      end

      {:json => qs}
    end

    action :get_question_detail, :get, :api => true do |params|
      q = get_question_by_id(params[:id])

      {:json => pick_question_info_with_options(q)}
    end

    action :get_current_question_detail, :get, :api => true do |params|
      q = get_table("voting").find_one("is_current" => true)

      {:json => pick_question_info_with_options(q)}
    end

    # 对多选的问题，api的形式应该是形如"AC"，一个字符串仅包含选中的选项
    # 标签。
    action :submit_vote, :post, :api => true do |params|
      user = get_friend("userslist").get_user_by_id(params[:user_id])
      username = if user then user["name"] else "<不详>" end
      vote_item = {
        "user_id" => params[:user_id],
        "name" => username,
        "submitted_at" => Time.now
      }

      q = get_question_by_id(params[:question_id])

      if q.nil? then
        {:json => {:err => "no such question"}}
      elsif q["question_type"] == "multiple_choice" then
        commit_multiple_choice_vote(
          ensure_bson_id(params[:question_id]),
          params[:option_tag],
          vote_item)
      else
        commit_single_choice_vote(
          ensure_bson_id(params[:question_id]),
          params[:option_tag],
          vote_item)
      end
    end

    private

    def ensure_bson_id(_id)
      begin
        BSON::ObjectId(_id)
      rescue BSON::InvalidObjectId
        nil
      end
    end

    def get_question_by_id(_id)
      begin
        if _id.is_a? String then
          _id = BSON::ObjectId(_id)
        end
        get_table("voting").find_one("_id" => _id, "_kind" => "question")
      rescue BSON::InvalidObjectId
        nil
      end
    end

    def commit_multiple_choice_vote(question_id, raw_option_tags, vote_item)
      option_tags = raw_option_tags.split(//).uniq

      os = get_table("voting").find(
        {"question_id" => question_id,
          "option_tag" => {"$in" => option_tags}}).to_a

      get_table("voting").update(
        {"question_id" => question_id,
          "option_tag" => {"$in" => option_tags}},
        {"$push" => {"users" => vote_item}},
        {:multi => true})

      if os.length == option_tags.length then
        {:json => {:ok => true}}
      else
        accepted_options = os.map {|o| o["option_tag"]}
        ignored_options = option_tags - accepted_options
        {:json => {:ok => true,
            :accepted_options => accepted_options.join,
            :ignored_options => ignored_options.join}}
      end      
    end

    def commit_single_choice_vote(question_id, option_tag, vote_item)
      o = get_table("voting").find_one(
        {"question_id" => question_id, "option_tag" => option_tag})
    
      if o then
        get_table("voting").update(
          {"question_id" => question_id,
            "option_tag" => option_tag},
          {"$push" => {"users" => vote_item}})

        {:json => {:ok => true}}
      else
        {:json => {:err => "no such option: #{option_tag}"}}
      end
    end

    def pick_question_info(q)
      if q then
        {"_id" => q["_id"].to_s,
          "question_text" => q["question_text"],
          "question_type" => q["question_type"],
          "is_current" => !!q["is_current"],
          "create_at" => q["create_at"]}
      else
        {}
      end
    end

    def pick_question_info_with_options(q)
      q_info = pick_question_info(q)

      os = get_table("voting").find({"_kind" => "option", "question_id" => q["_id"]}).map do |o|
        {"option_text" => o["option_text"],
          "option_tag" => o["option_tag"],
          "users" => o["users"]}
      end

      q_info["options"] = os

      q_info
    end
  #   PhysicalLinkDepth = 4

  #   class NoUploadedFileError < RuntimeError; end
  #   class NoSuchFolderError < RuntimeError; end

  #   action :admin, :get do |params|
  #     if params[:current_folder_id] then
  #       current_folder_id = params[:current_folder_id] 
  #       current_folder = get_file_by_id(current_folder_id)
  #       children_ids = current_folder["children_ids"] || []
  #       children = get_table("files").find({"_id" => {"$in" => children_ids}})

  #       {:file => "views/admin.slim",
  #         :locals => {:current_folder_id => current_folder_id,
  #           :current_folder => current_folder,
  #           :children => children}}      
  #     else 
  #       {:redirect_to => "admin?current_folder_id=#{get_root_folder_id}"}
  #     end
  #   end

  #   action :thumbs, :get do |params|
  #     current_folder_id = params[:current_folder_id] 
  #     current_folder = get_file_by_id(current_folder_id)
  #     children_ids = current_folder["children_ids"] || []
  #     children = get_table("files").find({"_id" => {"$in" => children_ids}}).to_a

  #     {:file => "views/thumbs.slim",
  #       :locals => {:current_folder_id => current_folder_id,
  #         :current_folder => current_folder,
  #         :children => children}}
  #   end

  #   action :new_folder, :get do |params|
  #     current_folder_id = params[:current_folder_id] 
  #     current_folder = get_file_by_id(current_folder_id)

  #     {:file => "views/new_folder.slim",
  #       :locals => {:current_folder_id => current_folder_id,
  #         :current_folder => current_folder}}
  #   end

  #   action :create_folder, :post do |params|
  #     name = if params[:name].blank? then 
  #              get_default_name
  #            else 
  #              params[:name]
  #            end

  #     current_folder_id = params[:current_folder_id]
  #     new_folder_id = get_table("files").insert(
  #       "name" => name,
  #       "parent_id" => BSON::ObjectId(current_folder_id),
  #       "is_folder" => true,
  #       "create_at" => Time.now)
  #     get_table("files").update(
  #       {"_id" => BSON::ObjectId(current_folder_id)},
  #       {"$addToSet" => {"children_ids" => new_folder_id}})
  #     {:redirect_to => "admin?current_folder_id=#{current_folder_id}"}
  #   end

  #   action :new_file, :get do |params|
  #     current_folder_id = params[:current_folder_id] 
  #     current_folder = get_file_by_id(current_folder_id)

  #     {:file => "views/new_file.slim",
  #       :locals => {:current_folder_id => current_folder_id,
  #         :current_folder => current_folder}}
  #   end

  #   action :create_file, :post do |params|
  #     begin
  #       create_file_with_upload(
  #         params[:current_folder_id], params[:name], params[:file])
  #       {:redirect_to => "admin?current_folder_id=#{params[:current_folder_id]}"}
  #     rescue NoUploadedFileError
  #       {:text => "error: no uploaded file"}
  #     rescue NoSuchFolderError
  #       {:text => "error: current folder does not exist"}
  #     end
  #   end

  #   action :new_link_file, :get do |params|
  #     current_folder_id = params[:current_folder_id] 
  #     current_folder = get_file_by_id(current_folder_id)

  #     {:file => "views/new_link_file.slim",
  #       :locals => {:current_folder_id => current_folder_id,
  #         :current_folder => current_folder}}
  #   end

  #   action :create_link_file, :post do |params|
  #     current_folder_id = params[:current_folder_id] 
  #     current_folder = get_file_by_id(current_folder_id)
  #     link = params[:link]
  #     if link.blank? then
  #       {:text => "link should not be empty"}
  #     else
  #       name = if params[:name].blank? then
  #                File.basename(link, ".*")
  #              else
  #                params[:name]
  #              end

  #       insert_file_record(name, link, current_folder_id)
  #       {:redirect_to => "admin?current_folder_id=#{current_folder_id}"}
  #     end
  #   end

  #   action :edit_name, :get do |params|
  #     current_folder_id = params[:current_folder_id] 
  #     f_id = params[:f_id]
  #     f = get_file_by_id(f_id)

  #     {:file => "views/edit_name.slim",
  #       :locals => {:current_folder_id => current_folder_id,
  #         :f => f}}
  #   end

  #   action :update_name, :post do |params|
  #     name = if params[:new_name].blank? then
  #              get_default_name
  #            else 
  #              params[:new_name]
  #            end

  #     current_folder_id = params[:current_folder_id]
  #     f_id = params[:f_id]

  #     get_table("files").update(
  #       {"_id" => BSON::ObjectId(f_id)},
  #       {"$set" => {"name" => name}})
  #     {:redirect_to => "admin?current_folder_id=#{current_folder_id}"}
  #   end

  #   # 参数：如果f_id对应一个目录，将会给出这个目录的名字、_id和目录下的
  #   # 所有文件、子目录的id、名字和链接。如果f_id对应一个文件，则会给出
  #   # 这个文件的id、名字和链接。f_id可以为空，这时会默认为根目录。如果
  #   # 链接以http://开头，表示是外部链接，否则表示是内部链接。内部链接需
  #   # 要在前面加上会务平台服务器的地址才能访问。
  #   action :list, :get, :api => true do |params|
  #     f_id = if params[:f_id].blank? then
  #              get_root_folder_id
  #            else
  #              params[:f_id]
  #            end
  #     f = get_file_by_id(f_id)

  #     if f.nil? then
  #       {:json => {:error => "wrong f_id"}}
  #     elsif f["is_folder"] then
  #       children_ids = f["children_ids"] || []
  #       children = get_table("files").find({"_id" => {"$in" => children_ids}})
  #       children_hashes = children.map do |ch|
  #         ch_data = {:_id => ch["_id"].to_s, :name => ch["name"]}
  #         if ch["is_folder"] then
  #           ch_data[:is_folder] = true
  #         else
  #           ch_data[:link] = ch["physical_link"] unless ch["is_folder"]
  #         end
  #         ch_data
  #       end
  #       {:json => {
  #           :_id => f["_id"].to_s,
  #           :name => f["name"],
  #           :is_folder => true,
  #           :children => children_hashes}}
  #     else
  #       {:json => {
  #           :_id => f["_id"].to_s,
  #           :name => f["name"],
  #           :link => f["physical_link"]}}
  #     end
  #   end

  #   # 接受四个参数：folder_id、user_id、name和file。其中folder_id是要上
  #   # 传到的目录的id，name表示在系统中所取的文件名，file则应该是一段
  #   # multipart的数据，表示文件内容。成功上传时返回{"ok": true}。
  #   action :upload, :post, :api => true do |params|
  #     begin
  #       user = get_friend("userslist").get_user_by_id(params[:user_id])
  #       username = if user then user["name"] else "" end

  #       create_file_with_upload(
  #         params[:folder_id], params[:name], params[:file], username)
  #       {:json => {:ok => true}}
  #     rescue NoUploadedFileError
  #       {:json => {:error => "no uploaded file"}}
  #     rescue NoSuchFolderError
  #       {:json => {:error => "wrong folder_id"}}
  #     end      
  #   end

  #   private

  #   def get_root_folder_id
  #     root = get_table("files").
  #       find_one("name" => "/", "parent_id" => nil, "is_folder" => true)

  #     if root then
  #       root["_id"].to_s
  #     else
  #       get_table("files").
  #         insert("name" => "/", "parent_id" => nil, "is_folder" => true)
  #       get_root_folder_id
  #     end
  #   end

  #   def get_file_by_id(_id)
  #     begin
  #       if _id.is_a? String then
  #         _id = BSON::ObjectId(_id)
  #       end
  #       get_table("files").find_one("_id" => _id)
  #     rescue BSON::InvalidObjectId
  #       nil
  #     end
  #   end

  #   def get_random_relative_physical_link(extname)
  #     dirs = (0...PhysicalLinkDepth).map { SecureRandom.hex(1) }
  #     filename = SecureRandom.hex(16) + extname
  #     ["/system", *dirs, filename].join("/")
  #   end

  #   def insert_file_record(name, link, current_folder_id, uploader_name="")
  #     new_file_id = get_table("files").insert(
  #       "name" => name,
  #       "physical_link" => link,
  #       "parent_id" => BSON::ObjectId(current_folder_id),
  #       "creator" => uploader_name,
  #       "is_folder" => false,
  #       "create_at" => Time.now)
  #     get_table("files").update(
  #       {"_id" => BSON::ObjectId(current_folder_id)},
  #       {"$addToSet" => {"children_ids" => new_file_id}})
  #   end

  #   def get_default_name
  #     "未命名#{Time.now.getlocal.strftime('%Y%m%d%H%M%S')}"
  #   end

  #   def create_file_with_upload(folder_id, name, uploaded_file, uploader_name="")
  #     folder = get_file_by_id(folder_id)
      
  #     raise NoUploadedFileError if uploaded_file.nil? 
  #     raise NoSuchFolderError if folder.nil?
        
  #     original_filename = uploaded_file.original_filename
  #     tempfile_path = uploaded_file.tempfile.path
  #     final_name = if name.blank? then
  #                    File.basename(original_filename, ".*")
  #                  else
  #                    name
  #                  end
  #     extname = File.extname(original_filename)

  #     begin  # caution! this is an "end while" pattern
  #       physical_link = get_random_relative_physical_link(extname)
  #       absolute_physical_path = File.join(Rails.root, "public", physical_link)
  #     end while File.exists?(absolute_physical_path)

  #     FileUtils.mkdir_p(File.dirname(absolute_physical_path))
  #     FileUtils.mv(tempfile_path, absolute_physical_path)
  #     insert_file_record(final_name, physical_link, folder_id, uploader_name)
  #   end
  end
end
