class HuiMain
  Db = Mongo::MongoClient.new(DB_CONFIG[:server]).db(DB_CONFIG[:db])
  Events = Db.collection("events")
  PluginData = Db.collection("plugin_data")

  def self.events
    Events
  end

  def self.plugin_data
    PluginData
  end
end
