# -*- coding: utf-8 -*-
require 'spec_helper'

require 'fileutils'

describe "fileslist" do
  include BasicHelpers

  before(:all) do
    FileUtils.mv(File.join(Rails.root, "public/system/"),
      File.join(Rails.root, "public/system_temp/"))
  end

  after(:all) do
    FileUtils.rm_rf(File.join(Rails.root, "public/system/"))
    FileUtils.mv(File.join(Rails.root, "public/system_temp/"),
      File.join(Rails.root, "public/system/"))
  end

  before(:each) do
    clear_db
  end

  before(:each) do
    login_with_dummy
    create_and_enter_an_event
    enter_fileslist_management
  end

  def enter_fileslist_management
    click_on_row "fileslist", "管理插件"
    page.should have_content "文件管理"
  end

  it "uploads file" do
    click_on "上传新文件"
    page.should have_content "当前目录：/"
    fill_in :name, :with => "用户表"
    attach_file :file, get_test_file("users.csv")
    click_on "提交"
    page.should have_content "用户表.csv"
  end

  it "creates folder" do
    click_on "创建新目录"
    fill_in :name, :with => "这个"
    click_on "在当前目录下创建新目录"
    page.should have_content "这个"
  end

  it "creates file under subfolder" do
    click_on "创建新目录"
    fill_in :name, :with => "这个"
    click_on "在当前目录下创建新目录"
    page.should have_content "这个"

    click_on "这个"

    click_on "上传新文件"
    page.should have_content "当前目录：这个"
    fill_in :name, :with => "用户表"
    attach_file :file, get_test_file("users.csv")
    click_on "提交"
    page.should have_content "用户表.csv"

    click_on "去上级目录"
    page.should have_no_content "csv"
  end
end
