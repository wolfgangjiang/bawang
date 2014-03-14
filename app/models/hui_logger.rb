class HuiLogger
  def self.log(user_id, user_name, event_id, plugin_code_name, action, args)
    begin
      HuiMain.logs.insert(
        :submitted_at => Time.now,
        :user_id => user_id,
        :user_name => user_name,
        :event_id => event_id,
        :plugin_code_name => plugin_code_name,
        :action => action,
        :args => args)
    rescue
      HuiMain.logs.insert(
        :submitted_at => Time.now,
        :user_id => user_id,
        :user_name => user_name,
        :event_id => event_id,
        :plugin_code_name => plugin_code_name,
        :action => action,
        :args => JSON.generate(args)) # <== maybe args key containing "." caused error
    end  
  end
end
