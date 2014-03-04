unless defined? DB_CONFIG
  path = File.join(Rails.root, "config/db_config.yml")
  DB_CONFIG = YAML.load_file(path)[Rails.env].with_indifferent_access
end
