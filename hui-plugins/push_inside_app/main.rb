module HuiPluginPool
  class PushInsideApp < GenericHuiPlugin
    def admin(params)
      messages = get_table("messages").find.to_a.reverse
      {:file => "views/admin.slim",
        :locals => {
          :messages => messages,
          :event_id => params[:event_id]}}
    end

    def create(params)
      get_table("messages").insert(
        :text => params[:message], :active => false)
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
        {:text => m["text"]}
      end
      {:json => data}
    end
  end
end

