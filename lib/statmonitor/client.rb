#!/usr/bin/ruby

require 'base64'
require 'json'
require 'openssl'
require 'socket'

require 'statmonitor'

module StatMonitor
  #This class represents a stat monitor client. Each monitored machine runs a client.
  #
  #==Encryption
  #Many of the messages sent between the client and server are encrypted as follows:
  #* The data are encrypted with a 128-bit AES CBC cipher using the key specified in the configuration file.
  #* The 128-bit initialization vector used for the cipher is prepended to the encrypted data.
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
  #* Convert the integer representing the time to a string and encrypt it
  #* Calculate the MD5 checksum of the encrypted data in binary format (using Digest:MD5.digest() instead of hexdigest())
  #* Concatenate the checksum and the encrypted data, then encode them in base64 format
  #* Initiate a TCP connection with the client
  #* Send the encoded time to the client, followed by an EOT character
  #
  #When the connection is made, the client will:
  #
  #* Attempt to receive the message up to the newline, timing out if there is a long enough gap in transmission
  #* Verify that the checksum is correct
  #* Decode and decrypt the message
  #* Parse the message as an integer
  #* Compare the timestamp in the message to the current system time
  #* Ensure that the timestamp is within 15 minutes of the client's local time
  #* Generate the JSON structure
  #* Send the value of the "Status" field as a plaintext decimal integer with an EOT terminator
  #* Encrypt the JSON structure, convert it to Base64 format, and send it to the server with an EOT terminator
  #  - If it is not possible to encrypt the data, the status message is "1", and the JSON message is not sent.
  #* Close the connection to the client
  #
  #===Error messages
  #If there is a protocol- or network-related error on the client side, the status message will be nonzero.
  #The values of the status codes and the "Message" field are defined as follows:
  #* If the public key file is missing or invalid, status = 1. The JSON structure will not be sent.
  #* If the server's message was too short, status = 2, and "Message" = "Invalid message length".
  #* If the checksum is not valid, status = 3, and "Message" = "Invalid checksum".
  #* If the timestamp provided in the message is not within 15 minutes of the client's time, status = 4, and "Message" = "Timestamp does not match local time".
  #* If there is an error while obtaining the JSON data, status = 5, and "Message" = "Error while obtaining statistics"
  class Client
    #The message returned if the command message has an invalid length
    INVALID_LENGTH_MESSAGE = {'Status' => 2, 'Message' => 'Invalid message length'}

    #Creates the client with a given configuration object.
    #For details on the configuration object, see the docs for StatMonitor::Config.
    def initialize(config)
      @config = config

      @connections = 0
      @running = true
      @mutex = Mutex.new

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

      #Write the PID file.
      File.open(@config.pid_file, "w") do |pid_file|
        pid_file.puts(Process.pid.to_s)
      end

      @config.log.debug("Started with PID " << Process.pid.to_s)

    end

    #Runs the client. This function is meant to be run after the client is
    #daemonized, and it will not return until a SIGTERM is received.
    def run()
      server = nil

      begin
        server = TCPServer.new(@config.port)

        Signal.trap("TERM") do
          exit if @connections == 0
          @running = false
          @mutex.synchronize do
            @config.log.debug("Stopping client...")
          end
        end

        @config.log.debug("Started client")
        
        #Monitor incoming packets.
        
        while @running do
          Thread.start(server.accept) do |client|
            address = client.addr[3]
            begin
              begin
                @mutex.synchronize{@connections += 1}

                @mutex.synchronize do
                  @config.log.debug("Connection accepted from #{address}")
                end

                wrapper = EOTSocketWrapper.new(client)

                #Is there a key?
                if @config.key
                  message = wrapper.read_until_eot(@config.timeout)

                  #If process_message raises an exception, catch it for now
                  #so the client can be notified.
                  data = nil
                  data_exception = nil
                  begin
                    data = process_message(message)
                  rescue => e
                    data = {'Status' => 5, 'Message' => 'Error while obtaining statistics'}
                    data_exception = e
                  end

                  response = JSON.generate(data)

                  response = Base64.encode64(StatMonitor::aes_128_cbc_encrypt(response, @config.key))

                  status = data['Status']

                  #This may throw an error if the connection closes.
                  wrapper.send_message(status.to_s)
                  wrapper.send_message(response)

                  #If there was an error while obtaining statistics, raise the
                  #error now.
                  raise data_exception if data_exception

                  if status != 0
                    @mutex.synchronize do
                      msg = "Error while communicating with #{address}: #{data['Message']}"
                      @config.syslog.err(msg)
                      @config.log.error(msg)
                    end
                  end
                else
                  wrapper.send_message("1")
                  raise 'No valid encryption key present'
                end
              ensure
              client.close unless client.closed?
              @mutex.synchronize do
                @connections -= 1
                @config.log.debug("Connection to #{address} closed")
              end
            end
            #Catch and log any errors.
            rescue => e
              @mutex.synchronize do
                @config.syslog.err(e.message)
                @config.log.error("#{e.message}\n#{e.backtrace.join("\n")}")
              end
            end
            #If an uncaught error somehow managed to get here, we should know about it.
            #We'll have to just kill the program.
            #This should only happen if there's a serious issue with logging.
          end.abort_on_exception = true #End thread
        end #End server loop
      ensure
        FileUtils.rm(@config.pid_file) if File.exists? @config.pid_file
        server.close if server
        @mutex.synchronize do
          @config.log.debug("Client stopped")
        end
      end
    end

    #Processes a network message, including checksum verification, decryption, etc.
    #Probably only useful for unit tests or when called by the run() method.
    def process_message(message)
      #Is there a message?
      if message then
        message = Base64.decode64(message)
        #Is the result long enough? Is it properly padded?
        if message.length < (16 + 32) || message.length % 16 != 0
          puts "Invalid length: #{message.length}"
          return INVALID_LENGTH_MESSAGE
        end

        sentChecksum = message[0 .. 15]
        message = message[16 .. -1]
        actualChecksum = Digest::MD5.digest(message)

        if sentChecksum == actualChecksum
          message = StatMonitor::aes_128_cbc_decrypt(message, @config.key)
          puts message
          remoteTime = message.to_i
          localTime = Time.new.to_i

          if remoteTime < (localTime + (60 * 15)) && remoteTime > (localTime - (60 * 15))
            return @stats.get
          else
            #Invalid timestamp
            return {'Status' => 4, 'Message' => 'Timestamp does not match local time'}
          end
        else
          #Invalid checksum
          return {'Status' => 3, 'Message' => 'Invalid checksum'}
        end
      else
        #Message was too short
        return INVALID_LENGTH_MESSAGE
      end
    end
  end
end
