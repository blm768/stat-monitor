#!/usr/bin/ruby

require 'base64'
require 'json'
require 'openssl'
require 'socket'

require 'statmonitor'

module StatMonitor
  #This class represents a stat monitor client.
  class Client
    #Creates the client with a given configuration object.
    #For details on the configuration object, see the docs for StatMonitor::Config.
    def initialize(config)
      @config = config

      @processing = false
      @running = true

      @publicKey = OpenSSL::PKey::RSA.new(File.read config.public_key_file)

      @socket = nil

      @stats = StatMonitor::LocalStats.new(config)
    end

    #Daemonizes the current process. Duplicates the functionality of
    #Process.daemonize() because it is not available in all Ruby versions.
    def daemonize()
      exit if fork
      Process.setsid
      exit if fork
      Dir.chdir "/"
      STDIN.reopen "/dev/null"
      STDOUT.reopen "/dev/null"
      STDERR.reopen "/dev/null"
    end

    #Runs the client. This function is meant to be run after the client is
    #daemonized, so it enters an infinite loop and will not return.
    def run()
      @socket = TCPServer.new(@config.port)

      Signal.trap("STOP") do
        exit unless @processing
        @running = false
      end
      
      #Monitor incoming packets.
      
      while @running do
        Thread.start(@socket.accept) do |client|
          @processing = true

          message = readFirstLineWithTimeout(client)

          client.puts(JSON.generate(process_message(message)))
          
          client.close

          @processing = false
        end
      end
    end

    #Processes a network message, including checksum verification, decryption, etc.
    #Probably only useful for unit tests or when called by the run() method.
    def process_message(message)
      #Is there a long enough message?
      if message && message.length > 16 then
        message = Base64.decode64(message)
        sentChecksum = message[0 .. 15]
        message = message[16 .. -1]
        actualChecksum = Digest::MD5.digest(message)

        if sentChecksum == actualChecksum
          message = @publicKey.public_decrypt(message) 
          remoteTime = message.to_i
          localTime = Time.new.to_i

          if remoteTime < (localTime + (60 * 15)) && remoteTime > (localTime - (60 * 15))
            return @stats.get
          else
            #Invalid timestamp
            return {'Status' => 3, 'Message' => 'Timestamp does not match local time'}
          end
        else
          #Invalid checksum
          return {'Status' => 2, 'Message' => 'Invalid checksum'}
        end
      else
        #Message was too short
        return {'Status' => 1, 'Message' => 'Invalid message length'}
      end
    end

    #Reads the first line sent over the socket, potentially discarding data sent afterward. If the connection times out
    #before the newline is read, returns nil
    def readFirstLineWithTimeout(client)
      buf = ""
      loop do
        gotMessage = IO.select([client], nil, nil, @config.timeout)

        return nil unless gotMessage
        
        #To do: check for EOFError? (probably shouldn't appear with select())
        msg = client.readpartial(1024)
        nlIndex = msg.index("\n")

        if nlIndex then
          return buf + msg[0 ... nlIndex]
        else
          buf += msg
        end
      end
    end

    private :readFirstLineWithTimeout

  end
end
