module HuiPluginPool
  class Dummy < GenericHuiPlugin
    action :admin, :get do |params|
      {:text => "dummy admin page here"}
    end
  end
end
