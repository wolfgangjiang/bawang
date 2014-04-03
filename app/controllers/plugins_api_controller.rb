class PluginsApiController < PluginsController
  protect_from_forgery with: :null_session
  skip_before_filter :login_required

  def is_api
    true
  end
end
