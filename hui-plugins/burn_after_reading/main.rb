# -*- coding: utf-8 -*-
require 'csv'

module HuiPluginPool
  class BurnAfterReading < GenericHuiPlugin
    action :admin, :get do |params|
      folder_info = get_friend("fileslist").list_folder(params[:current_folder_id])
      current_folder = folder_info["folder"]
      children = folder_info["children"].to_a
      current_folder_id = current_folder["_id"].to_s

      burn_data_array = get_table("burn_after_reading").find(
        "f_id" => {"$in" => children.map {|c| c["_id"].to_s}})
      burn_data = make_hash_with(burn_data_array, "f_id")

      children.each do |ch|
        ch["limit_times"] = (burn_data[ch["_id"].to_s] || {})["limit_times"]
      end

      {:file => "views/admin.slim",
        :locals => {:current_folder_id => current_folder_id,
          :current_folder => current_folder,
          :children => children}}
    end

    action :edit, :get do |params|
      f = get_friend("fileslist").get_file_by_id(params[:f_id])
      limit = get_limit(params[:f_id])
      if limit["passcode"].blank?
        limit["passcode"] = gen_default_passcode
        set_passcode(params[:f_id], limit["passcode"])
      end        

      {:file => "views/edit.slim",
        :locals => {:file => f,
          :limit => limit}}
    end

    action :update, :post do |params|
      get_table("burn_after_reading").update(
        {"f_id" => params[:f_id]},
        {"$set" => {
            "limit_times" => params[:limit_times].to_i,
            "passcode" => params[:passcode]}},
        {:upsert => true})

      {:redirect_to => "admin"}
    end

    action :cancel_constraint, :post do |params|
      get_table("burn_after_reading").update(
        {"f_id" => params[:f_id]},
        {"$unset" => {"limit_times" => 1}},
        {:upsert => true})      

      {:redirect_to => "admin"}
    end

    action :get_limit_times, :get, :api => true do |params|
      {:json => {:limit_times => get_limit(params[:f_id])["limit_times"]}}
    end

    action :get_passcode, :get, :api => true do |params|
      passcode = get_limit(params[:f_id])["passcode"]
      if passcode.blank?
        passcode = gen_default_passcode
        set_passcode(params[:f_id], passcode)
      end

      {:json => {:passcode => passcode}}
    end

    private

    def make_hash_with(iterable, key)
      hash = {}
      iterable.each do |item|
        hash[item[key].to_s] = item
      end
      hash
    end

    def get_limit(f_id)
      limit = get_table("burn_after_reading").find_one({"f_id" => f_id})

      limit || {}
    end

    def gen_default_passcode
      # 在文件中不一定事先有对应的passcode，对这种情况，我们在edit和
      # get_passcode中临时生成并且存进数据库，这样保证用户总是能看到
      # passcode存在，而且一经随机生成就不会再修改。
      chars = ("0".."9").to_a + ("a".."z").to_a
      6.times.map { chars[(rand * chars.length).to_i] }.join
    end

    def set_passcode(f_id, passcode)
      get_table("burn_after_reading").update(
        {"f_id" => f_id},
        {"$set" => {"passcode" => passcode}},
        {:upsert => true})
    end
  end
end
