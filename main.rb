require 'sinatra'
require './log_listener.rb'
require './tail_server.rb'

# Sinatra options
configure do
  set :bind, '0.0.0.0'
end

udp_port = 15372

if not ARGV[0]
  puts "You need to specify the listening UDP port"
  puts "Assuming #{udp_port}"
else
  udp_port = ARGV[0]
end

the_log_listener = LogListener.new

puts 'Trying to log in to Dropbox...'
the_log_listener.login_to_dropbox

puts "Starting Listener on UDP port #{udp_port}..."
Thread.new {
  the_log_listener.start_listening(udp_port)
}

get '/save' do
  the_log_listener.save_now
  return
end

