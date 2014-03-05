# -*- coding: utf-8 -*-
module HuiPluginPool
  class CommentInsideApp < GenericHuiPlugin
    def admin(params)
      messages = get_table("messages").find.to_a.reverse
      {:file => "views/admin.slim",
        :locals => {
          :messages => messages,
          :event_id => params[:event_id]}}
    end

    def create(params)
      get_table("messages").insert(
        :text => params[:message],
        :author_name => params[:author_name],
        :active => false,
        :create_at => Time.now)
      {:redirect_to => "admin"}
    end

    def toggle(params)
      object_id = BSON::ObjectId(params[:_id]) 
      message = get_table("messages").find_one("_id" => object_id)
      get_table("messages").update({"_id" => object_id},
        {"$set" => {:active => (not message["active"])}})
      {:redirect_to => "admin"}
    end

    def api_poll(params)
      data = get_table("messages").find(:active => true).map do |m|
        {:text => m["text"],
          :author_name => m["author_name"],
          :create_at => m["create_at"]}
      end
      {:json => data}
    end

    def api_submit(params)
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
