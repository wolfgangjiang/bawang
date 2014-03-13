class SessionsController < ApplicationController
  skip_before_filter :login_required

  def new
  end

  def create
    if params[:email] == "admin@edoctor.cn" and
        params[:password] == "Sh123456" then
      session[:current_user_id] = "admin"
      session[:current_user_name] = "admin@edoctor.cn"
    end
    HuiLogger.log(nil, session[:current_user_name], nil, "general_admin", "login", {})
    redirect_to "/"
  end

  def destroy
    reset_session
    redirect_to "/"
  end
end
