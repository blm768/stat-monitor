#!/usr/bin/ruby

require 'base64'
require 'json'
require 'openssl'
require 'socket'

require 'statmonitor'

module StatMonitor
  class Client
    def initialize(config)
      @config = config

      @processing = false
      @running = true

      @publicKey = OpenSSL::PKey::RSA.new(File.read config.public_key)

      @socket = TCPServer.new(config.port)
    end

    def daemonize()
      exit if fork
      Process.setsid
      exit if fork
      Dir.chdir "/"
      STDIN.reopen "/dev/null"
      STDOUT.reopen "/dev/null"
      STDERR.reopen "/dev/null"
    end

    def run()
      Signal.trap("STOP") do
        exit unless $processing
        $running = false
      end
      
      #Monitor incoming packets.
      
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
                client.puts(JSON.generate(StatMonitor::LocalStats.get)) 
              else
                #Invalid timestamp
                client.puts(JSON.generate({'Status' => 3, 'Message' => 'Timestamp does not match local time'}))
              end
            else
              #Invalid checksum
              client.puts(JSON.generate({'Status' => 2, 'Message' => 'Invalid checksum'}))
            end
          else
            #Message was too short
            client.puts(JSON.generate({'Status' => 1, 'Message' => 'Invalid message length'}))
          end
          
          client.close

          $processing = false
        end
      end
    end

    #Reads the first line sent over the socket, potentially discarding data sent afterward. If the connection times out
      #before the newline is read, returns nil
      def self.readFirstLineWithTimeout(timeout)
        buf = ""
        loop do
          gotMessage = IO.select([@socket], nil, nil, timeout)

          return nil unless gotMessage
          
          #To do: check for EOFError? (probably shouldn't appear with select())
          msg = @socket.readpartial(1024)
          nlIndex = msg.index("\n")

          if nlIndex then
            return buf + msg[0 ... nlIndex]
          else
            buf += msg
          end
        end
      end

      private_class_method :readFirstLineWithTimeout

  end
end
