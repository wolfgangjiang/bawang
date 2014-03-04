class PluginCollection
  def initialize(_type, event_id, plugin_code_name)
    @_type = _type
    @event_id = event_id
    @plugin_code_name = plugin_code_name
  end

  def with_scope(selector)
    selector.stringify_keys.merge(
      "_type" => @_type,
      "event_id" => @event_id,
      "plugin_code_name" => @plugin_code_name)
  end

  def find(selector={}, opts={})
    HuiMain.plugin_data.find(with_scope(selector), opts)
  end

  def find_one(selector={}, opts={}) 
    HuiMain.plugin_data.find_one(with_scope(selector), opts)
  end

  def insert(document, opts={})
    HuiMain.plugin_data.insert(with_scope(document), opts)
  end

  def update(selector, document, opts={})
    if document.keys.any? {|k| k.to_s.start_with? "$"} then
      HuiMain.plugin_data.update(with_scope(selector), document, opts)
    else
      HuiMain.plugin_data.update(
        with_scope(selector), with_scope(document), opts)
    end
  end

  def remove(selector={}, opts={})
    HuiMain.plugin_data.remove(with_scope(selector), opts)    
  end
end
