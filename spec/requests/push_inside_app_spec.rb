# -*- coding: utf-8 -*-
require 'spec_helper'

describe "push_inside_app_spec" do
  include BasicHelpers
  before(:each) do
    clear_db
    login_with_dummy
    create_and_enter_an_event
    add_plugin("push_inside_app")
    click_on_row "push_inside_app", "管理插件"
    page.should have_content "推送管理"
  end

  it "pushes message from admin" do
    fill_in :message, :with => "大家好"
    click_on "群发"
    page.should have_content "大家好"
    page.should have_content "隐藏"
  end

  it "toggles message status" do
    fill_in :message, :with => "大家好"
    click_on "群发"
    within_row "大家好" do
      click_on "切换状态"
    end
    page.should have_no_content "隐藏"
    page.should have_content "有效"
  end

  it "sends message through api" do
    fill_in :message, :with => "大家好"
    click_on "群发"
    within_row "大家好" do
      click_on "切换状态"
    end

    event_id = current_path.match(/[0-9a-f]{24}/).to_s
    get "/plugins/api/#{event_id}/push_inside_app/poll"
    data = JSON.parse(response.body)
    data.size.should == 1
    data[0]["text"].should == "大家好"
    (Time.parse(data[0]["create_at"]) - Time.now).abs.should < 1
  end
end
