# -*- coding: utf-8 -*-
require 'spec_helper'

describe "userslist" do
  include BasicHelpers

  before(:each) do
    clear_db
  end

  before(:each) do
    login_with_dummy
    create_and_enter_an_event
    enter_userslist_management
  end

  def enter_userslist_management
    click_on_row "userslist", "管理插件"
    page.should have_content "项目内的用户管理"
  end

  def import_a_user_csv(filename)
    click_on "批量导入csv"
    attach_file :file, get_test_file(filename)
    click_on "上传"
    page.should have_content "请确定每一列的含义"
    fill_in :initial_password, :with => "1234"
    selections = ["姓名", "城市", "舍弃", "手机号"]
    all(".column-names select").zip(selections).each do |sel, value|
      sel.select value
    end
    click_on "确定"
    page.should have_content "请确定是否正确"
    page.should have_content "朱元璋13811110001南京"
    click_on "确定"
    page.should have_content "项目内的用户管理"    
    HuiMain.plugin_data.find(:_type => "users").count.should == 3
    HuiMain.plugin_data.find(:_type => "users").map {|u| u["name"]}.to_set.
      should == ["朱元璋", "赵匡胤", "成吉思汗"].to_set
  end

  describe "user creation" do

    it "imports a csv" do
      import_a_user_csv "users.csv"

      HuiMain.plugin_data.find(:_type => "users").count.should == 3
      HuiMain.plugin_data.find(:_type => "users").map {|u| u["name"]}.to_set.
        should == ["朱元璋", "赵匡胤", "成吉思汗"].to_set
    end

    it "creates a user with form" do
      click_on "添加一个用户"
      fill_in :name, :with => "赵匡胤"
      fill_in :email, :with => "zhao.v@kaifeng.gov"
      fill_in :password, :with => "1234"
      click_on "完成"

      HuiMain.plugin_data.find(:_type => "users").count.should == 1
      HuiMain.plugin_data.find_one(:_type => "users")["name"].should == "赵匡胤"
    end
  end
end
