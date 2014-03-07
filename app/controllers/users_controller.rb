class UsersController < ApplicationController
  def index
    @users = HuiMain.users.find.sort(:_id => 1)
    @users_count = HuiMain.users.count
    @columns = HuiMain::UserColumns
    @human_columns = HuiMain::HumanUserColumns
  end

  def edit
    user = begin 
             HuiMain.users.find_one(:_id => BSON::ObjectId(params[:id]))
           rescue BSON::InvalidObjectId
             nil
           end
    render_404 unless user

    @user = user
    @columns = HuiMain::UserColumns
    @human_columns = HuiMain::HumanUserColumns
  end

  def update    
    user = begin 
             HuiMain.users.find_one(:_id => BSON::ObjectId(params[:id]))
           rescue BSON::InvalidObjectId
             nil
           end
    render_404 unless user

    data = params.slice(*HuiMain::UserColumns)
    HuiMain.users.update({:_id => user["_id"]}, {"$set" => data})
    redirect_to "/users"
  end
end
