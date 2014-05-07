# -*- coding: utf-8 -*-
require 'time'

module HuiPluginPool
  class CommentInsideApp < GenericHuiPlugin
    action :admin, :get do |params|
      messages = get_table("messages").find.to_a.reverse
      {:file => "views/admin.slim",
        :locals => {
          :messages => messages,
          :event_id => params[:event_id]}}
    end

    action :create, :post do |params|
      get_table("messages").insert(
        :text => params[:message],
        :author_name => params[:author_name],
        :active => false,
        :create_at => Time.now,
        :updated_at => Time.now)
      {:redirect_to => "admin"}
    end

    action :toggle, :post do |params|
      object_id = BSON::ObjectId(params[:_id]) 
      message = get_table("messages").find_one("_id" => object_id)
      get_table("messages").update({"_id" => object_id},
        {"$set" => {
            :active => (not message["active"]),
            :updated_at => Time.now}})
      {:redirect_to => "admin"}
    end

    action :poll, :get, :api => true do |params|
      if params[:updated_after] then
        begin
          time_limit = Time.parse(params[:updated_after])
        rescue
          return {:json => {:err => "cannot parse time string"}}
        end
        filter = {:active => true, :updated_at => {"$gt" => time_limit}}
      else
        filter = {:active => true}
      end

      data = get_table("messages").find(filter).map do |m|
        {:text => m["text"],
          :author_name => m["author_name"],
          :create_at => m["create_at"],
          :updated_at => m["updated_at"]}
      end
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
