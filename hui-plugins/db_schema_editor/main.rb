# -*- coding: utf-8 -*-
require 'csv'

module HuiPluginPool
  class DbSchemaEditor < GenericHuiPlugin
    class AsFriend < GenericHuiPlugin::AsFriend
    end

    action :admin, :get do |params|
      schema = read_var("schema")
      if schema.nil? or schema == "[]" then
        schema = nil
      end

      {:file => "views/admin.slim",
        :locals => {:schema => schema}}
    end

    action :clear, :post do |params|
      if Rails.env != "production" then
        clear_var("schema")
      else
        raise "cannot clear it in production mode"
      end

      {:redirect_to => "admin"}
    end

    action :edit, :get do |params|
      schema = read_var("schema")
      if schema.nil? or schema == "[]" then
        schema = "[]"
      end

      {:file => "views/edit.slim",
        :locals => {:schema => schema}}      
    end

    action :save, :post do |params|
      write_var("schema", params[:data_to_be_saved])
      {:redirect_to => "edit"}
    end
  end
end
