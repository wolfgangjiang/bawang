# -*- coding: utf-8 -*-
class HuiMain
  Db = Mongo::MongoClient.new(DB_CONFIG[:server]).db(DB_CONFIG[:db])
  Users = Db.collection("users")
  Events = Db.collection("events")
  PluginData = Db.collection("plugin_data")
  AsyncTasks = Db.collection("async_tasks")
  Logs = Db.collection("logs")

  UserColumns = ["name", "national_id", "mobile", "email", "city", "company",
    "department", "position"]
  HumanUserColumns = {
    "reject" => "舍弃",
    "name" => "姓名",
    "national_id" => "身份证号",
    "mobile" => "手机号",
    "email" => "电子邮箱",
    "city" => "城市",
    "company" => "工作单位",
    "department" => "部门/科室",
    "position" => "职位"}


  def self.users
    Users
  end

  def self.events
    Events
  end

  def self.plugin_data
    PluginData
  end

  def self.async_tasks
    AsyncTasks
  end

  def self.logs
    Logs
  end
end
