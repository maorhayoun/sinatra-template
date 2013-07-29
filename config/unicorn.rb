application       = "sinatra_template"
app_path          = "/var/www/#{application}"
 
environment 	  = ENV['RACK_ENV'] || 'development'
isDevelopment     = environment == 'development'

working_directory "#{app_path}/current"
pid               "#{app_path}/shared/tmp/pids/unicorn.pid"

unless isDevelopment
stderr_path       "#{app_path}/shared/log/unicorn.log"
stdout_path       "#{app_path}/shared/log/unicorn.log"
end

listen            "unix:/tmp/#{application}.unicorn.sock" , :backlog => 512
worker_processes  4
timeout           120
preload_app       true


preload_app true
if GC.respond_to?(:copy_on_write_friendly=)
  GC.copy_on_write_friendly = true
end

before_fork do |server, worker|
  old_pid = "#{server.config[:pid]}.oldbin"
  if File.exists?(old_pid) && server.pid != old_pid
    begin
      Process.kill("QUIT", File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
      # someone else did our job for us
    end
  end
end
