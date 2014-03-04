class SessionsController < ApplicationController
  skip_before_filter :login_required

  def new
  end

  def create
    if params[:email] == "admin@edoctor.cn" and
        params[:password] == "Sh123456" then
      session[:current_user_id] = "admin"
    end
    redirect_to "/"
  end

  def destroy
    reset_session
    redirect_to "/"
  end
end
