class PluginsController < ApplicationController
  before_filter :auto_reload_when_dev

  def dispatch_get
    handle
  end

  def dispatch_post
    handle
  end

  private

  def handle
    event = get_event_by_id(params[:event_id])
    return render_404 unless event

    plugin_code_name = params[:plugin_code_name]
    plugin = Plugins.get(params[:plugin_code_name])
    return render_404 unless plugin

    return render_404 unless event["plugins"].include? plugin_code_name

    resp = plugin.perform(
      get_plugin_action_method(params[:plugin_action]), params)
    process_response(resp, plugin_code_name)

    if resp.has_key?(:redirect_to) then
      path = File.join(
        "/plugins/#{params[:event_id]}/#{plugin_code_name}", resp[:redirect_to])
      redirect_to path # always get, no post
    else
      render resp
    end
  end
  
  def process_response(resp, plugin_code_name)
    unless resp.is_a? Hash and resp.keys.map(&:to_sym).any? {|k| [:file, :json, :redirect_to, :data, :xml, :text].include? k}
      raise "plugin action should return a hash with exactly one key of :file, :json, :redirect_to, :data, :xml or :text"
    end

    if resp.has_key?(:file) then
      resp[:file] =
        File.join(Plugins::PluginDirectory, plugin_code_name, resp[:file])
    end
  end

  def auto_reload_when_dev
    if Rails.env == "development" then
      Plugins.reload
    end
  end

  def get_plugin_action_method(plugin_action_name)
    plugin_action_name
  end
end
