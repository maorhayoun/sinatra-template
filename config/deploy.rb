# config/deploy.rb
require "bundler/capistrano"
#require "rvm-capistrano"

set :scm_user,        "maorhayoun"
set :scm_passphrase,  ""
set :server_ip,       "192.168.33.11"
set :repository,      "https://github.com/maorhayoun/sinatra-template.git"
set :rails_env,       "production"
set :application,     "sinatra_template"
set :deploy_to,       "/var/www/#{application}"

set :scm,             :git
set :branch,          "origin/master"
set :migrate_target,  :current
set :ssh_options,     { :forward_agent => true }
set :normalize_asset_timestamps, false
set :deploy_via,      :remote_cache

set :user,            "vagrant"
set :group,           "staff"
set :use_sudo,        true

role :web,    :server_ip
role :app,    :server_ip
role :db,     :server_ip, :primary => true

set(:latest_release)  { fetch(:current_path) }
set(:release_path)    { fetch(:current_path) }
set(:current_release) { fetch(:current_path) }

set(:current_revision)  { capture("cd #{current_path}; git rev-parse --short HEAD").strip }
set(:latest_revision)   { capture("cd #{current_path}; git rev-parse --short HEAD").strip }
set(:previous_revision) { capture("cd #{current_path}; git rev-parse --short HEAD@{1}").strip }

default_environment["RAILS_ENV"] = 'production'

# Use our ruby-1.9.2-p290@my_site gemset
#default_environment["PATH"]         = "--"
#default_environment["GEM_HOME"]     = "--"
#default_environment["GEM_PATH"]     = "--"
#default_environment["RUBY_VERSION"] = "ruby-1.9.2-p290"

#default_run_options[:shell] = 'bash'
default_run_options[:pty] = true

namespace :deploy do
  desc "Deploy your application"
  task :default do
    update
    restart
  end

  desc "Setup your git-based deployment app"
  task :setup, :except => { :no_release => true } do
    dirs = [deploy_to, shared_path]
    dirs += shared_children.map { |d| File.join(shared_path, d) }
    run "#{try_sudo} mkdir -p #{dirs.join(' ')} && #{try_sudo} chmod +w #{dirs.join(' ')}"
    run "#{try_sudo} git clone #{repository} #{current_path}"
  end

  task :cold do
    update
    migrate
  end

  task :update do
    transaction do
      update_code
    end
  end

  desc "Update the deployed code."
  task :update_code, :except => { :no_release => true } do
    run "cd #{current_path}; #{try_sudo} git fetch origin; #{try_sudo} git reset --hard #{branch}"
    sudo "chown -R #{user}:#{user} #{deploy_to}"    
    finalize_update
  end

  desc "Update the database (overwritten to avoid symlink)"
  task :migrations do
    transaction do
      update_code
    end
    migrate
    restart
  end

  task :finalize_update, :except => { :no_release => true } do
    run "chmod -R +w #{latest_release}" if fetch(:group_writable, true)

    # mkdir -p is making sure that the directories are there for some SCM's that don't
    # save empty folders
    run <<-CMD
      rm -rf #{latest_release}/log #{latest_release}/public/system #{latest_release}/tmp/pids &&
      mkdir -p #{latest_release}/public &&
      mkdir -p #{latest_release}/tmp &&
      ln -s #{shared_path}/log #{latest_release}/log &&
      ln -s #{shared_path}/system #{latest_release}/public/system &&
      ln -s #{shared_path}/pids #{latest_release}/tmp/pids &&
      #ln -sf #{shared_path}/database.yml #{latest_release}/config/database.yml
      #{try_sudo} ln -nf #{current_path}/config/nginx.conf /etc/nginx/sites-enabled/#{application} &&
      #{try_sudo} ln -nf 
      #TODO: ln to unicorn init
    CMD

    if fetch(:normalize_asset_timestamps, true)
      stamp = Time.now.utc.strftime("%Y%m%d%H%M.%S")
      asset_paths = fetch(:public_children, %w(images stylesheets javascripts)).map { |p| "#{latest_release}/public/#{p}" }.join(" ")
      run "find #{asset_paths} -exec touch -t #{stamp} {} ';'; true", :env => { "TZ" => "UTC" }
    end
  end

  desc "Zero-downtime restart of Unicorn"
  task :restart, :except => { :no_release => true } do
    run "kill -s USR2 `cat /tmp/unicorn.pid`"
  end

  desc "Start unicorn"
  task :start, :except => { :no_release => true } do
    run "cd #{current_path} ; #{try_sudo} bundle exec unicorn -c config/unicorn.rb -D"
  end

  desc "Stop unicorn"
  task :stop, :except => { :no_release => true } do
    run "kill -s QUIT `cat /tmp/unicorn.pid`"
  end

  namespace :rollback do
    desc "Moves the repo back to the previous version of HEAD"
    task :repo, :except => { :no_release => true } do
      set :branch, "HEAD@{1}"
      deploy.default
    end

    desc "Rewrite reflog so HEAD@{1} will continue to point to at the next previous release."
    task :cleanup, :except => { :no_release => true } do
      run "cd #{current_path}; #{try_sudo} git reflog delete --rewrite HEAD@{1}; #{try_sudo} git reflog delete --rewrite HEAD@{1}"
    end

    desc "Rolls back to the previously deployed version."
    task :default do
      rollback.repo
      rollback.cleanup
    end
  end
end

def run_rake(cmd)
  run "cd #{current_path}; #{rake} #{cmd}"
end
