class PluginsApiController < PluginsController
  protect_from_forgery with: :null_session
  skip_before_filter :login_required

  def get_plugin_action_method(plugin_action_name)
    "api_#{plugin_action_name}"
  end
end
