module HuiPluginPool
  class Dummy < GenericHuiPlugin
    def admin(params)
      {:text => "dummy admin page here"}
    end
  end
end
