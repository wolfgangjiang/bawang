class PluginsController < ApplicationController
  before_filter :auto_reload_when_dev

  def dispatch_get
    handle("get")
  end

  def dispatch_post
    handle("post")
    clean_params = params.except(:controller, :action, 
      :event_id, :plugin_code_name, :plugin_action,
      :utf8, :authenticity_token)
    HuiLogger.log(params[:user_id], get_user_name(params[:user_id]),
      params[:event_id], params[:plugin_code_name],
      params[:plugin_action], clean_params)
  end

  protected

  def handle(http_method)
    event = get_event_by_id(params[:event_id])
    return render_404 unless event

    plugin_code_name = params[:plugin_code_name]
    plugin = Plugins.get(params[:plugin_code_name])
    return render_404 unless plugin

    return render_404 unless event["plugins"].include? plugin_code_name

    begin
      resp = plugin.perform(params[:plugin_action], http_method, is_api, params)
      process_response(resp, plugin_code_name)
    rescue GenericHuiPlugin::NoSuchActionError
      render_404
    end

    if resp.has_key?(:redirect_to) then
      path = File.join(
        "/plugins/#{params[:event_id]}/#{plugin_code_name}", resp[:redirect_to])
      redirect_to path # always get, no post
    else
      @event_id = params[:event_id]
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
    resp[:layout] ||= "plugin"
  end

  def auto_reload_when_dev
    if Rails.env == "development" then
      Plugins.reload
    end
  end

  def is_api
    false
  end

  # maybe admin user from session or client-api user from params[:user_id]
  def get_user_name(user_id)
    if self.is_api then
      user = begin 
               HuiMain.plugin_data.find_one("_id" => BSON::ObjectId(user_id))
             rescue BSON::InvalidObjectId
               nil
             end
      if user then 
        user["name"]
      else
        nil
      end
    else # not api
      session[:current_user_name]
    end
  end
end
