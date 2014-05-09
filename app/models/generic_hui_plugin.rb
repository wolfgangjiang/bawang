class GenericHuiPlugin
  class NoSuchActionError < RuntimeError; end

  class AsFriend
    def initialize(event_id, plugin_code_name)
      @main_object = self.class.parent.new(event_id, plugin_code_name)
    end
  end

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

  def self.action(name, http_method, opt={}, &block)
    @@actions ||= {}.with_indifferent_access
    opt = opt.with_indifferent_access

    method_key = get_method_key(http_method, opt[:api])

    @@actions[method_key] ||= []
    @@actions[method_key] << name.to_s
    method_name = "#{method_key}_#{name}"
    define_method(method_name, &block)
  end

  def self.get_method_key(http_method, is_api)
    http_method = http_method.to_s

    if http_method == "get" and is_api then "get_api"
    elsif http_method == "get" and not is_api then "get_page"
    elsif http_method == "post" and is_api then "post_api"
    elsif http_method == "post" and not is_api then "post_page"
    else raise "unsupported http method #{http_method}"
    end    
  end

  def self.verify(name, http_method, is_api)
    method_key = get_method_key(http_method, is_api)
    raise NoSuchActionError.new(name) unless
      (@@actions[method_key] and
      @@actions[method_key].include?(name.to_s))
  end

  def perform(name, http_method, is_api, params)
    method_key = self.class.get_method_key(http_method, is_api)
    method_name = "#{method_key}_#{name}"
    self.send(method_name, params)
  end
end
