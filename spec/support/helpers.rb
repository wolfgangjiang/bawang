# -*- coding: utf-8 -*-
module BasicHelpers
  def clear_db
    HuiMain::Db.collections.each do |coll|
      unless coll.name.include? "system"
        coll.remove # remove all
      end
    end
  end

  def login_with_dummy
    visit "/"
    click_on "登录"
    current_path.should == "/"
  end

  def create_and_enter_an_event(event_name = "测试项目")
    click_on "创建新项目"
    fill_in :title, :with => event_name
    fill_in :desc, :with => "自动测试用"
    click_on "创建"
    page.should have_content event_name
    click_on "管理"
  end

  def click_on_row(row_feature, target_text)
    find(:xpath, "//tr[contains(.,'#{row_feature}')]/td/a", :text => target_text).
      click
  end

  def within_row(row_feature, &block)
    within(:xpath, "//tr[contains(.,'#{row_feature}')]", &block)
  end

  def get_test_file(filename)
    File.join(Rails.root, "spec/test_data", filename)    
  end

  def add_plugin(plugin_code_name)
    click_on "增减插件"
    within_row(plugin_code_name) do
      check("plugin_code_names[]")
    end
    click_on "提交"
    page.should have_content plugin_code_name
  end
end
