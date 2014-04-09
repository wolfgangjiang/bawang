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

  let(:event_id) { current_path.match(/[0-9a-f]{24}/).to_s }

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

    get "/plugins/api/#{event_id}/push_inside_app/poll"
    data = JSON.parse(response.body)
    data.size.should == 1
    data[0]["text"].should == "大家好"
    (Time.parse(data[0]["create_at"]) - Time.now).abs.should < 1
  end

  describe "route security" do
    it "prevents get request on post route" do
      path = "/plugins/#{event_id}/push_inside_app/post/toggle"

      expect do
        get path
      end.to raise_error ActionController::RoutingError
    end

    it "prevents api request on page route" do
      path = "/plugins/api/#{event_id}/push_inside_app/admin"

      expect do
        get path
      end.to raise_error ActionController::RoutingError
    end
  end
end

