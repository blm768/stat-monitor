#!/usr/bin/ruby

require 'base64'
require 'json'
require 'openssl'
require 'socket'

require 'statmonitor'

module StatMonitor
  module Client
    def self.run()
      #To do: make configurable?
      connectionPort = 9445

      $processing = false
      $running = true

      begin
        publicKey = OpenSSL::PKey::RSA.new(File.read '/etc/stat-monitor-client/public_key.pem')
      rescue
        puts "Unable to open public key file"
        exit 1
      end

=begin
      #Daemonize.
      exit if fork
      Process.setsid
      exit if fork
      Dir.chdir "/"
      STDIN.reopen "/dev/null"
      STDOUT.reopen "/dev/null"
      STDERR.reopen "/dev/null"
=end

      Signal.trap("STOP") do
        exit unless $processing
        $running = false
      end

      #Reads the first line sent over the socket, potentially discarding data sent afterward. If the connection times out
      #before the newline is read, returns nil
      def self.readFirstLineWithTimeout(socket, timeout)
        buf = ""
        loop do
          gotMessage = IO.select([socket], nil, nil, timeout)

          return nil unless gotMessage
          
          #To do: check for EOFError? (probably shouldn't appear with select())
          msg = socket.readpartial(1024)
          nlIndex = msg.index("\n")

          if nlIndex then
            return buf + msg[0 ... nlIndex]
          else
            buf += msg
          end
        end
      end
      
      #Monitor incoming packets.
      socket = TCPServer.new(connectionPort)
      while $running do
        Thread.start(socket.accept) do |client|
          $processing = true

          #To do: make timeout configurable?
          message = readFirstLineWithTimeout(client, StatMonitor::LocalStats.timeout)

          #Is there a long enough message?
          if message && message.length > 16 then
            message = Base64.decode64(message)
            sentChecksum = message[0 .. 15]
            message = message[16 .. -1]
            actualChecksum = Digest::MD5.digest(message)

            if sentChecksum == actualChecksum
              message = publicKey.public_decrypt(message) 
              remoteTime = message.to_i
              localTime = Time.new.to_i

              if remoteTime < (localTime + (60 * 15)) && remoteTime > (localTime - (60 * 15))
                client.write(JSON.generate(StatMonitor::LocalStats.get)) 
              else
                #Invalid timestamp; ignore
                #To do: log these events?
              end
            end
          end
          
          client.close

          $processing = false
        end
      end
    end

        #Stuff for unit testing
    def self.test()
      privateKey = OpenSSL::PKey::RSA.new(File.read('/etc/stat-monitor-client/private_key.pem'))

      encrypted = privateKey.private_encrypt(Time.new.to_i.to_s)
      checksum = Digest::MD5.digest(encrypted)
      message = Base64.encode64(checksum + encrypted).gsub(/\n/, "")

      socket = TCPSocket.open('127.0.0.1', 9445)
      socket.puts(message)

      gotMessage = IO.select([socket], nil, nil, 3)

      if gotMessage
        return socket.gets
      end

      nil
    end
  end
end
