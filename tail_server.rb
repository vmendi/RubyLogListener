require 'socket'

class TailServer

  def start_serving port

    server = TCPServer.new port

    thr = Thread.new {
      loop do
        @client = server.accept    # Wait for a client to connect (1 and only 1)

        while @client
          command = @client.recv(4096)

          if not command
            close_socket
          else
            yield command.chomp()
          end
        end
      end
    }

  end

  def send_to_clients msg
    begin
      if @client
        @client.sendmsg msg
      end
    rescue
       close_socket
    end
  end

  def close_socket
    if @client
      @client.close
      @client = nil
    end
  end

end