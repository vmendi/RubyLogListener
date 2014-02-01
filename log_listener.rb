require 'rubygems'
require 'bundler/setup'

require 'socket'
require 'date'
require 'dropbox_sdk'

class LogListener

  # From DropBox
  APP_KEY = ''
  APP_SECRET = ''

  # ACCESS_TYPE should be ':dropbox' or ':app_folder' as configured for your app
  ACCESS_TYPE = :app_folder

  # The file where we keep our access_token
  DROPBOX_ACCESS_FILE = 'dropbox.key'
  LOGS_DIR = './logs/'

  ###
  #
  ###
  def initialize
    create_logs_dir
  end

  ###
  #
  ###
  def login_to_dropbox
    session = DropboxSession.new(APP_KEY, APP_SECRET)

    # Make the user sign in and authorize this token
    if File.exists? DROPBOX_ACCESS_FILE
      File.open(DROPBOX_ACCESS_FILE, 'r') do |file|
        access_token_key = file.readline.strip
        access_token_secret = file.readline.strip
        session.set_access_token access_token_key, access_token_secret
      end
    else
      session.get_request_token
      authorize_url = session.get_authorize_url
      puts "\nGo to this url and click 'Authorize' to get the token:\n#{authorize_url}"
      CGI.parse(authorize_url.split('?').last)
      puts "\nOnce you authorize the app on Dropbox, press enter... "
      $stdin.gets.chomp

      access_token = session.get_access_token

      File.open(DROPBOX_ACCESS_FILE, 'w') do |file|
        file.puts access_token.key
        file.puts access_token.secret
      end
    end

    @dropbox_client = DropboxClient.new(session, ACCESS_TYPE)
    puts 'Linked Dropbox Account:', @dropbox_client.account_info().inspect

  end

  ###
  # Wanna test it? nc -u 127.0.0.1 15372
  ###
  def start_listening port

    listening_socket = UDPSocket.new
    listening_socket.bind('0.0.0.0', port)

    # Old method, saving to dropbox only when our date changes
    @last_file_name = look_for_most_recent_log

    while true
      # This blocks until X bytes are received
      packet = listening_socket.recvfrom(4096)

      file_name = LOGS_DIR + DateTime.now.strftime('%d %b %Y %a') + '.txt'  # "Sun 04 Feb 2001"

      received_line = packet[0] + "\r\n"

      File.open(file_name, 'a') do |file|
        file.write(received_line)
      end

      # save_to_dropbox file_name
      save_to_dropbox_only_on_date_change file_name
    end

  end

  ###
  # Saves to dropbox only when it's a new day.
  ###
  def save_to_dropbox_only_on_date_change(file_name)
    if @last_file_name and file_name != @last_file_name
      save_to_dropbox @last_file_name
    end
    @last_file_name = file_name
  end

  ###
  # Saves to dropbox
  ###
  def save_to_dropbox(file_name)
    Thread.new {
      if file_name
        file = open(file_name)
        response = @dropbox_client.put_file(File.basename(file_name), file, true)
      end
    }
  end

  ###
  # Creates our output folder
  ###
  def create_logs_dir
    unless File.directory? LOGS_DIR
      Dir::mkdir LOGS_DIR
    end
  end

  def save_now
    save_to_dropbox look_for_most_recent_log
  end

  ###
  # Returns the file_name for the most recent log in our LOGS_DIR folder
  ###
  def look_for_most_recent_log
    newest_time = nil
    newest_file = nil

    Dir.foreach(LOGS_DIR) do |dirEntry|
      dirEntry = LOGS_DIR + dirEntry
      if is_log_file dirEntry
        if (newest_time == nil || (File.mtime(dirEntry) <=> newest_time) > 0)
          newest_time = File.mtime(dirEntry)
          newest_file = dirEntry
        end
      end
    end

    newest_file
  end

  ###
  #
  ###
  def is_log_file dirEntry
    !File.directory?(dirEntry) && (File.extname(dirEntry) == '.txt')
  end

end


