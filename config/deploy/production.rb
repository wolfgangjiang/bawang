set :stage, :production

set :rails_env, "production"
set :application, "hui_prod"
set :branch, "master"
set :user, "edoctor"
set :deploy_to, "/srv/#{fetch(:application)}"

server "unknown yet", user: "edoctor", roles: %w{web app db}
