# config valid only for Capistrano 3.1
lock '3.1.0'

set :application, 'my_app_name'
set :repo_url, 'git@g.edr.im:ruby/hui.git'
set :use_sudo, false
set :deploy_timestamped, true
set :release_name, Time.now.localtime.strftime("%Y%m%d%H%M%S")
set :keep_releases, 5
set :rvm_ruby_version, "2.0.0"

# Default branch is :master
# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }

# Default deploy_to directory is /var/www/my_app
# set :deploy_to, '/var/www/my_app'

# Default value for :scm is :git
# set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
# set :log_level, :debug

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
set :linked_files, %w{.ruby-version .ruby-gemset config/db_config.yml config/ldap.yml}

# Default value for linked_dirs is []
set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets public/system}

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }
# set :default_env, { :path => "/home/edoctor/.nvm/v0.10.18/bin:$PATH" }

namespace :deploy do
  task :start do
    on roles(:app) do
      within release_path do
        set :rvm_path, "~/.rvm"
        execute :bundle, "exec", "unicorn_rails", "-c", File.join(release_path, "config/unicorn.rb"), "-E", fetch(:rails_env), "-D"
      end
    end
  end

  task :stop do
    on roles(:app) do
      pid_file = File.join(release_path, "tmp/pids/unicorn.pid")
      execute "if [[ -e #{pid_file} ]]; then kill $(cat #{pid_file}); fi"
    end
  end

  desc 'Restart application'
  task :restart do
    invoke "deploy:stop"
    invoke "deploy:start"
  end

  # task :restart do
  #   on roles(:app), in: :sequence, wait: 5 do
  #     # Your restart mechanism here, for example:
  #     # execute :touch, release_path.join('tmp/restart.txt')
  #   end
  # end

  after :publishing, :restart
  after :finishing, 'deploy:cleanup'

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end
end
