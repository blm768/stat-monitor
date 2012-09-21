module StatMonitor
  #Wraps a socket so messages are separated by EOT characters
  class EOTSocketWrapper
    attr_reader :socket

    #Creates a new EOTSocketWrapper around a socket
    def initialize(socket)
      @socket = socket
      @buf = ''
    end

    #Reads from the socket until an EOT is found
    #
    #Extra characters may be read from the socket, but they are
    #kept in a buffer to be used with the next call to read_until_eot().
    #If there is a gap in transmission longer than the timeout, nil will
    #be returned. The total time spent waiting for data may be longer than the
    #timeout.
    #If the timeout is nil, the read will never time out.
    def read_until_eot(timeout)
      #Read until eot or timeout.
      eot_index = @buf.index("\004")
      received = nil
      gotMessage = nil

      #Do we already have a message ready?
      unless eot_index
        #Read until EOT or timeout
        while gotMessage = IO.select([@socket], nil, nil, timeout) do
          received = @socket.readpartial(1024) rescue nil
          break unless received

          eot_index = received.index("\004")

          @buf << received

          if eot_index
            eot_index += @buf.length - received.length
            break
          end
        end

        #If we didn't find an EOT, return nil.
        return nil unless eot_index
      end

      message = @buf[0 ... eot_index]

      @buf = @buf[eot_index + 1 .. -1]

      return message
    end

    #Sends the message followed by an EOT
    #
    #The message must not contain any EOT characters.
    def send_message(message)
      @socket.write(message)
      @socket.write("\004")
    end
  end
end