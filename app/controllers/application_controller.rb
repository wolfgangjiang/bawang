class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  before_filter :login_required

  def login_required
    redirect_to '/sessions/new' unless session[:current_user_id]
  end

  def current_user
    raise "not implemented yet"
    # @current_user ||= 
  end

  def render_404
    raise ActionController::RoutingError.new('Not Found')
  end

  def get_event_by_id(_id)
    begin
      HuiMain.events.find_one(:_id => BSON::ObjectId(_id))
    rescue BSON::InvalidObjectId
      nil
    end    
  end
end
