#!/usr/bin/ruby

require 'base64'
require 'json'
require 'openssl'
require 'socket'

require 'statmonitor'

module StatMonitor
  #This class represents a stat monitor client. Each monitored machine runs a client.
  #
  #==Data format
  #Information is sent from the client to the server as a JSON structure. Its fields are defined as follows:
  #* "Processors": an integer representing the number of processors
  #* "Memory": a dictionary containing the following items:
  #  * "Total": the total amount of physical memory
  #  * "Cached": the amount of cached physical memory
  #  * "Free": the amount of free physical memory as a percentage of total physical memory
  #  * "Swap": the total amount of swap space
  #  * "SwapCached": the amount of cached swap space
  #  * "SwapFree": the amount of free swap space as a percentage of total swap space
  #
  #* "Disks": a dictionary with disk names as the keys and floating-point numbers representing disk usage percentages as the values
  #* "Load": an array of three numbers representing the 5-, 10-, and 15-minute load averages as percentages
  #* "Users": an array containing the name of each user that is currently logged in
  #* "Status": 0 indicates success; any other value represents a network or protocol error.
  #* "Message": Holds any error messages produced. If there is no error, the value is the string "OK".
  #
  #If the value of any field cannot be reliably determined, the field will be encoded as a null value. Field values should not be null in any other situation.
  # 
  #==Protocol
  #
  #Each client listens on TCP port 9445 for a connection from the server. When the server wishes to retrieve load data,
  #it performs the following steps:
  #
  #* Retrieve the current system time as seconds from the Unix epoch in GMT
  #* Convert the integer representing the time to a string and encrypt it with the RSA key specified in the configuration file
  #* Calculate the MD5 checksum of the encrypted data in raw binary format (using Digest:MD5.digest() instead of hexdigest())
  #* Concatenate the checksum and the encrypted data, then encode them in base64 format
  #* Remove any newline characters in the encoded string
  #* Initiate a TCP connection with the client
  #* Send the encoded time to the client, followed by a newline character
  #
  #When the connection is made, the client will:
  #
  #* Attempt to receive the message up to the newline, timing out if there is a long enough gap in transmission
  #* Verify that the checksum is correct
  #* Decode and decrypt the message
  #* Parse the message as an integer
  #* Compare the timestamp in the message to the current system time
  #* Ensure that the timestamp is within 15 minutes of the client's local time
  #* Send the JSON data to the client as a single line terminated with a newline character
  #* Close the connection to the client
  #
  #===Error messages
  #If there is a protocol- or network-related error on the client side, only the "Status" and "Message" fields will be
  #present in the JSON message. Their values are defined as follows:
  #* If the server's message was too short, "Status" = 1, and "Message" = "Invalid message length".
  #* If the checksum is not valid, "Status" = 2, and "Message" = "Invalid checksum".
  #* If the timestamp provided in the message is not within 15 minutes of the client's time, "Status" = 3, and "Message" = "Timestamp does not match local time".
  #* If the public key file is missing or invalid, "Status" = 4, and "Message" = "Invalid key provided; unable to decrypt message"
  #* If the private key file is missing or invalid, "Status" = 5, and "Message" = "Invalid key provided; unable to encrypt message"
  class Client
    #Creates the client with a given configuration object.
    #For details on the configuration object, see the docs for StatMonitor::Config.
    def initialize(config)
      @config = config

      @connections = 0
      @running = true
      @mutex = Mutex.new

      @private_key = OpenSSL::PKey::RSA.new(File.read config.private_key_file)

      @socket = nil

      @stats = StatMonitor::LocalStats.new(config)
    end

    #Daemonizes the current process and creates a PID file.
    def daemonize()
      exit if fork
      Process.setsid
      exit if fork
      Dir.chdir "/"
      STDIN.reopen "/dev/null"
      STDOUT.reopen "/dev/null"
      STDERR.reopen "/dev/null"

      #Write the PID file if possible.
      begin
        pid_file = File.open(@config.pid_file, "w")
        pid_file.puts(Process.pid.to_s)
      ensure
        pid_file.close unless pid_file.nil?
      end

    end

    #Runs the client. This function is meant to be run after the client is
    #daemonized, so it enters an infinite loop and will not return.
    def run()
      begin
        @socket = TCPServer.new(@config.port)

        Signal.trap("TERM") do
          exit if @connections == 0
          @running = false
        end
        
        #Monitor incoming packets.
        
        while @running do
          Thread.start(@socket.accept) do |client|
            @mutex.synchronize{@connections += 1}

            message = readFirstLineWithTimeout(client)

            response = JSON.generate(process_message(message))

            #To do: figure out why encryption makes the code hang.
            #response = Base64.encode(@private_key.private_encrypt(response))

            client.puts(response)
            
            client.close

            @mutex.synchronize{@connections -= 1}
          end
        end
      ensure
        FileUtils.rm(@config.pid_file) if File.exists? @config.pid_file
        @socket.close
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
          #Is there a public key?
          unless @config.public_key
            return {'Status' => 4, 'Message' => 'Invalid key provided; unable to decrypt message'}
          end

          message = @config.public_key.public_decrypt(message) 
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
        
        msg = client.readpartial(1024)
        nlIndex = msg.index("\n")

        if nlIndex then
          return buf << msg[0 ... nlIndex]
        else
          buf << msg
        end
      end
    end

    private :readFirstLineWithTimeout

  end
end
