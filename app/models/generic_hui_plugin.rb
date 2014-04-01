class GenericHuiPlugin
  def initialize(event_id, plugin_code_name)
    @plugin_code_name = plugin_code_name
    @event_id = event_id
  end

  def get_table(table_name)
    PluginCollection.new(table_name, @event_id, @plugin_code_name)
  end

  def get_friend(friend_plugin_code_name)
    Plugins.get(friend_plugin_code_name).
      as_friend_class.new(@event_id, friend_plugin_code_name)
  end

  def get_event_title
    event = HuiMain.events.find_one({:_id => BSON::ObjectId(@event_id)})
    if event then
      event["title"]
    else
      nil
    end
  end

  def write_var(name, value)
    name_s = name.to_s
    get_table("var").update(
      {:name => name_s},
      {"$set" => {name_s => value}},
      {:upsert => true})
  end

  def read_var(name)
    name_s = name.to_s
    rec = get_table("var").find_one(:name => name_s)
    if rec then
      rec[name_s]
    else
      nil
    end
  end

  def clear_var(name)
    name_s = name.to_s
    get_table("var").remove(:name => name_s)
  end
end
