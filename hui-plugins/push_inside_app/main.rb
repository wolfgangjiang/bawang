# -*- coding: utf-8 -*-
module HuiPluginPool
  class PushInsideApp < GenericHuiPlugin
    action :admin, :get do |params|
      error_message = read_var("error_message")
      clear_var("error_message")

      messages = get_table("push_messages").find.to_a.reverse
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
        get_table("push_messages").insert(
          :text => params[:message],
          :active => false,
          :create_at => Time.now,
          :updated_at => Time.now)
      end
      {:redirect_to => "admin"}
    end

    action :toggle, :post do |params|
      object_id = BSON::ObjectId(params[:_id]) 
      message = get_table("push_messages").find_one("_id" => object_id)
      get_table("push_messages").update({"_id" => object_id},
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

      data = get_table("push_messages").find(filter).map do |m|
        {:text => m["text"],
          :create_at => m["create_at"],
          :updated_at => m["updated_at"]}
      end
      {:json => data}
    end
  end
end
