set :stage, :semiprod

set :rails_env, "production"
set :application, "hui_semi_prod"
set :branch, "master"
set :user, "edoctor"
set :deploy_to, "/srv/#{fetch(:application)}"

server "222.73.115.145", user: "edoctor", roles: %w{web app db}
