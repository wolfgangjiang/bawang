# -*- coding: utf-8 -*-
module HuiPluginPool
  class Voting < GenericHuiPlugin
    HumanQuestionTypes = {
      "single_choice" => "单选",
      "multiple_choice" => "多选"
    }

    HumanValidationResult = {
      :ok => "有效",
      :duplicated => "重复投票",
      :not_on_time => "不在规定时间内",
      :unrecognized => "不在规定选项内"
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
        {"$set" => {
            "is_current" => true,
            "started_at" => Time.now}})

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
        "relative_deadline" => params[:relative_deadline],
        "permit_duplicate" => !!params[:permit_duplicate],
        "vote_items" => [],
        "option_ids" => []);
      {:redirect_to => "admin"}
    end

    action :question, :get do |params|
      q = get_question_by_id(params[:id])
      os = get_table("voting").find(        
        {"_id" => {"$in" => q["option_ids"]},
          "_kind" => "option"}).to_a
      compute_votes(q, os)

      {:file => "views/question.slim",
        :locals => {:question => q,
          :options => os,
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
            "question_type" => sanitized_question_type,
            "relative_deadline" => params[:relative_deadline],
            "permit_duplicate" => !!params[:permit_duplicate]}})
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

    action :poll_question_status, :get do |params|
      q = get_question_by_id(params[:id])

      remaining_time_message =
        if q["started_at"].blank? then
          "尚未开始"
        else
          started_at = "（开始时间 #{q['started_at'].getlocal}）"
          if q["relative_deadline"].blank? then
            "正在进行#{started_at}"
          else
            deadline = q["started_at"] + q["relative_deadline"].to_i
            if deadline < Time.now then
              "已经结束#{started_at}"
            else
              remaining_time = (deadline - Time.now).to_i
              "剩余时间：#{remaining_time} 秒#{started_at}"
            end
          end
        end

      os = get_table("voting").find(        
        {"_id" => {"$in" => q["option_ids"]},
          "_kind" => "option"}).to_a
      compute_votes(q, os)

      {:json => {
          :remaining_time_message => remaining_time_message,
          :options => os}}
    end

    action :vote_items, :get do |params|
      q = get_question_by_id(params[:q_id])
      os = get_table("voting").find(        
        {"_id" => {"$in" => q["option_ids"]},
          "_kind" => "option"}).to_a
      compute_votes(q, os)

      {:file => "views/vote_items.slim",
        :locals => {
          :question => q,
          :vote_items => q["vote_items"],
          :human_validation_result => HumanValidationResult}}
    end

    action :unrecognized_vote_items, :get do |params|
      q = get_question_by_id(params[:q_id])
      os = get_table("voting").find(        
        {"_id" => {"$in" => q["option_ids"]},
          "_kind" => "option"}).to_a
      compute_votes(q, os)

      {:file => "views/unrecognized_vote_items.slim",
        :locals => {:question => q,
          :vote_items => q["unrecognized_vote_items"],
      :human_validation_result => HumanValidationResult}}
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
      q = get_question_by_id(params[:q_id])
      os = get_table("voting").find(        
        {"_id" => {"$in" => q["option_ids"]},
          "_kind" => "option"}).to_a
      compute_votes(q, os)
      o = os.find {|op| op["_id"].to_s == params[:o_id]}

      {:file => "views/option.slim",
        :locals => {
          :q_id => params[:q_id],
          :option => o,
          :human_validation_result => HumanValidationResult}}
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
        "_id" => BSON::ObjectId.new,
        "user_id" => params[:user_id],
        "name" => username,
        "submitted_at" => Time.now,
        "option_tag" => params[:option_tag]
      }

      q = get_question_by_id(params[:question_id])

      if q.nil? then
        {:json => {:err => "no such question"}}
      else
        get_table("voting").update(
          {"_id" => q["_id"],
            "_kind" => "question"},
          {"$push" => {"vote_items" => vote_item}})
        {:json => {:ok => true}}
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

    def pick_question_info(q)
      if q then
        {"_id" => q["_id"].to_s,
          "question_text" => q["question_text"],
          "question_type" => q["question_type"],
          "is_current" => !!q["is_current"],
          "create_at" => q["create_at"],
          "relative_deadline" => q["relative_deadline"],
          "vote_items" => q["vote_items"].map {|v| v.except("_id")}}
      else
        {}
      end
    end

    def pick_question_info_with_options(q)
      q_info = pick_question_info(q)

      os = get_table("voting").find(        
        {"_id" => {"$in" => q["option_ids"]},
          "_kind" => "option"}).to_a
      compute_votes(q, os)

      q_info["options"] = os.map do |o|
        o.except("_id", "_kind", "vote_items", "question_id")
      end

      q_info
    end

    def compute_votes(q, os)
      if q["question_type"] == "multiple_choice" then
        compute_multiple_choice_votes(q, os)
      else
        compute_single_choice_votes(q, os)
      end
    end

    def compute_single_choice_votes(q, os)
      q["unrecognized_vote_items"] = []
      os.each do |o|
        o["count"] = 0
        o["vote_items"] = []
      end

      q["vote_items"].each do |v|
        v["validation"] = validate_vote(q, v)
        o = os.find {|op| op["option_tag"] == v["option_tag"]}
        if o then
          o["vote_items"] << v
          o["count"] += 1 if v["validation"] == :ok
        else
          q["unrecognized_vote_items"] << v
          v["validation"] = :unrecognized
        end
      end
    end

    def compute_multiple_choice_votes(q, os)
      q["unrecognized_vote_items"] = []
      os.each do |o|
        o["count"] = 0
        o["vote_items"] = []
      end

      q["vote_items"].each do |v|
        v["validation"] = validate_vote(q, v)
        selected_os = os.select {|op| v["option_tag"].include? op["option_tag"]}
        if selected_os.length > 0 then
          selected_os.each do |o|
            o["vote_items"] << v
            o["count"] += 1 if v["validation"] == :ok
          end
        else
          q["unrecognized_vote_items"] << v
          v["validation"] = :unrecognized
        end
      end
    end

    def validate_vote(q, v)
      if not is_valid_vote_on_time(q, v) then
        :not_on_time
      elsif not is_valid_vote_on_duplication(q, v) then
        :duplicated
      else
        :ok
      end
    end

    def is_valid_vote_on_time(q, v)
      # 不在规定时间内的投票无效
      if q["started_at"].blank? then
        false
      elsif q["relative_deadline"].blank? then
        v["submitted_at"] > q["started_at"]
      else
        v["submitted_at"] > q["started_at"] and
          v["submitted_at"] < q["started_at"] + q["relative_deadline"].to_i
      end
    end

    def is_valid_vote_on_duplication(q, v)
      if q["permit_duplicate"] then
        true
      else
        same_user_votes =
          q["vote_items"].select { |vt| vt["user_id"] == v["user_id"] }
        same_user_votes_valid_on_time =
          same_user_votes.select { |vt| is_valid_vote_on_time(q, vt) }
        if same_user_votes_valid_on_time.empty?
          true
        else
          earliest_id = same_user_votes_valid_on_time.
            map {|vt| vt["_id"].to_s}.min
          earliest_id.to_s == v["_id"].to_s
        end
      end
    end
  end
end
