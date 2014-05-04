class SessionsController < ApplicationController
  skip_before_filter :login_required
  layout "session_layout"


  def new
  end

  def create
    if Rails.env == "test" then
      session[:current_user_id] = "test"
      session[:current_user_name] = "test_dummy"
      redirect_to "/"
      return
    end

    ldap_name = params[:email].match(/(.*)@edoctor\.cn/)[1] rescue nil
    if ldap_name then
      user_info = LDAP.auth(ldap_name, params[:password])
      if user_info then
        session[:current_user_id] = ldap_name
        session[:current_user_name] = user_info[:display_name]
        HuiLogger.log(session[:current_user_id], session[:current_user_name],
          nil, "general_admin", "admin_login", {})
      else
        flash[:message] = "login failed"
      end
    else
      flash[:message] = "login failed"
    end

    redirect_to "/"
  end

  def destroy
    reset_session
    redirect_to "/"
  end
end
