class GenericHuiPlugin
  def initialize(event_id, plugin_code_name)
    @plugin_code_name = plugin_code_name
    @event_id = event_id
  end

  def get_table(table_name)
    PluginCollection.new(table_name, @event_id, @plugin_code_name)
  end
end
