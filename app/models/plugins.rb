class Plugins
  attr_reader :code_name, :human_name, :mandatory
  attr_reader :controller_class, :as_friend_class
  PluginDirectory = File.join(Rails.root, "hui-plugins")

  def initialize(opt)
    opt.each do |name, value|
      self.instance_variable_set("@#{name}", value)
    end
  end

  def self.reload
    @@plugins = []
    Object.send(:remove_const, "HuiPluginPool") if defined? HuiPluginPool

    plugin_dirs = Dir.glob(File.join(PluginDirectory, "*"))
    plugin_dirs.each do |p_dir|
      manifest = YAML.load_file(File.join(p_dir, "manifest.yml"))
      load File.join(p_dir, "main.rb")
      plugin_class_name = File.basename(p_dir).camelize
      plugin_class = HuiPluginPool.const_get(plugin_class_name)
      as_friend_class = if plugin_class.const_defined?("AsFriend") then
                          plugin_class.const_get("AsFriend")
                        else
                          nil
                        end
      @@plugins << self.new(
        :code_name => File.basename(p_dir),
        :human_name => manifest["name"],
        :mandatory => manifest["mandatory"],
        :controller_class => plugin_class,
        :as_friend_class => as_friend_class)
    end
  end

  def self.get(plugin_code_name)
    @@plugins.find {|p| plugin_code_name == p.code_name}
  end

  def self.list
    @@plugins
  end

  def perform(name, params)
    self.controller_class.
      new(params[:event_id], params[:plugin_code_name]).
      send(name, params)
  end

  self.reload # first time load
end
