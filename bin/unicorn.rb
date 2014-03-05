case ARGV[0]
when "start"
  `bundle exec unicorn_rails -c ./config/unicorn.rb -E production -D`
when "stop"
  `kill $(cat ./tmp/pids/unicorn.pid)`
when "graceful_stop"
  `kill -s QUIT $(cat ./tmp/pids/unicorn.pid)`
when "reload"
  `kill -s USR2 $(cat ./tmp/pids/unicorn.pid)`
when "restart"
  `kill -s QUIT $(cat ./tmp/pids/unicorn.pid)`
  `bundle exec unicorn_rails -c ./config/unicorn.rb -E production -D`
else
  puts "unknown arg: " + ARGV[0].to_s
end
