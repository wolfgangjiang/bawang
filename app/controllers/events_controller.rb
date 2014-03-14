class EventsController < ApplicationController
  def index
    @events = HuiMain.events.find.to_a
  end

  def new
  end

  def create
    mandatory_plugins = Plugins.list.select {|p| p.mandatory}.map(&:code_name)
    HuiMain.events.insert(
      :title => params[:title],
      :create_at => Time.now,
      :creator => session[:current_user_name],
      :desc => params[:desc],
      :plugins => mandatory_plugins)
    redirect_to :action => :index
  end

  def show
    event = get_event_by_id(params[:id])

    if event then
      event_plugin_names = event["plugins"] || []
      @event = event
      @event_plugins = event_plugin_names.map {|name| Plugins.get(name)}
      @event_plugins_is_empty = (event_plugin_names.length == 0)
    else
      render_404
    end
  end

  def plugin_select
    event = get_event_by_id(params[:id])

    if event then
      @event = event
      @event_plugin_names = event["plugins"] || []
      @all_plugins = Plugins.list
    else
      render_404
    end
  end

  def plugin_change
    event = get_event_by_id(params[:id])

    if event then
      selected_plugin_code_names = params[:plugin_code_names] || []
      mandatory_plugins = Plugins.list.select {|p| p.mandatory}.map(&:code_name)
      plugin_code_names = mandatory_plugins + selected_plugin_code_names
      HuiMain.events.update({:_id => event["_id"]},
        {"$set" => {"plugins" => plugin_code_names}})
    else
      render_404
    end

    redirect_to "/events/#{params[:id]}"
  end

  def clear
    if Rails.env == "production" then
      render :text => "clearing data is not allowed in production mode"
    else
      event = get_event_by_id(params[:id])
      
      if event then
        HuiMain.plugin_data.remove(:event_id => event['_id'].to_s)
      else
        HuiMain.plugin_data.remove
      end
      redirect_to "/events/#{params[:id]}"
    end
  end
end
