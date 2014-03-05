set :stage, :staging

set :rails_env, "development"
set :application, "hui_staging"
set :branch, "development"
set :user, "edoctor"
set :deploy_to, "/srv/#{fetch(:application)}"

server "192.168.10.128", user: "edoctor", roles: %w{web app db}
