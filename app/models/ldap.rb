class LDAP
  Config = YAML.load_file(File.expand_path('config/ldap.yml', Rails.root))[Rails.env]

  def self.auth(username, password)
    ldap = Net::LDAP.new
    ldap.host = Config['host']
    ldap.port = Config['port'] || 389
    ldap.auth "sh\\" + username, password

    if ldap.bind then
      {:display_name => ldap_userinfo(ldap)[:displayname][0]} rescue nil
    else
      nil
    end
  end

  private

  def self.ldap_userinfo(ldap)
    username = ldap.instance_variable_get("@auth")[:username]
    user_principal_name = username.match(/^sh\\(?<name>.*?)$/)[:name]
    filter = Net::LDAP::Filter.eq("userPrincipalName", "#{user_principal_name}*")

    search(ldap, filter, {
        :attributes => [
          'cn', 'title', 'samaccountname',
          'mail', 'mobile', 'pager', 'displayname'
        ]
      })[0]
  end

  def self.search(ldap, filter, opts = {})
    ldap.search({
        :base => 'DC=sh,DC=ed',
        :filter => filter
      }.merge!(opts))
  end
end
