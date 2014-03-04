class EventsController < ApplicationController
  def index
    @events = HuiMain.events.find.to_a
  end

  def new
  end

  def create
    HuiMain.events.insert(
      :title => params[:title],
      :start_date => params[:start_date],
      :finish_date => params[:finish_date])
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
      plugin_code_names = params[:plugin_code_names] || []
      HuiMain.events.update({:_id => event["_id"]},
        {"$set" => {"plugins" => plugin_code_names}})
    else
      render_404
    end

    redirect_to "/events/#{params[:id]}"
  end
end
