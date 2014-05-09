# -*- coding: utf-8 -*-
require 'time'

module HuiPluginPool
  class CommentInsideApp < GenericHuiPlugin
    action :admin, :get do |params|
      error_message = read_var("error_message")
      clear_var("error_message")

      messages = get_table("messages").find.sort("updated_at" => -1)
      {:file => "views/admin.slim",
        :locals => {
          :messages => messages,
          :error_message => error_message,
          :event_id => params[:event_id]}}
    end

    action :create, :post do |params|
      if params[:message].blank? then
        write_var("error_message", "不能发送空消息")
      else
        get_table("messages").insert(
          :text => params[:message],
          :author_name => params[:author_name],
          :active => false,
          :create_at => Time.now,
          :updated_at => Time.now)
      end
      {:redirect_to => "admin"}
    end

    action :toggle_active, :post do |params|
      object_id = BSON::ObjectId(params[:id]) 
      message = get_table("messages").find_one("_id" => object_id)
      get_table("messages").update({"_id" => object_id},
        {"$set" => {
            :active => (not message["active"]),
            :updated_at => Time.now}})
      {:redirect_to => "admin"}
    end

    action :bump, :post do |params|
      get_table("messages").update(
        {"_id" => BSON::ObjectId(params[:id])},
        {"$set" => {:updated_at => Time.now}})
      {:redirect_to => "admin"}
    end

    action :poll, :get, :api => true do |params|
      if params[:updated_after] then
        begin
          time_limit = Time.parse(params[:updated_after])
        rescue
          return {:json => {:err => "cannot parse time string"}}
        end
        time_filter = {:updated_at => {"$gt" => time_limit}}
      else
        time_filter = {}
      end

      appended = get_table("messages").find(time_filter.merge(:active => true)).map do |m|
        {:_id => m["_id"].to_s,
          :text => m["text"],
          :author_name => m["author_name"],
          :updated_at => m["updated_at"]}
      end

      removed = get_table("messages").find(time_filter.merge(:active => false)).map do |m|
        {:_id => m["_id"].to_s,
          :updated_at => m["updated_at"]}
      end

      data = {
        :appended => appended,
        :removed => removed,
      }

      {:json => data}
    end

    action :submit, :post, :api => true do |params|
      user = get_friend("userslist").get_user_by_id(params[:user_id])
      author_name = if user then user["name"] else "<未知>" end

      get_table("messages").insert(
        :text => params[:message],
        :author_name => author_name,
        :active => false,
        :create_at => Time.now)
      {:json => {:ok => true}}
    end
  end
end
