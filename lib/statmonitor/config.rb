require 'logger'
require 'syslog'

module StatMonitor
  #This class represents configuration data for the various classes in StatMonitor.
  #
  #==Configuration file format
  #The configuration file is a JSON structure with the following fields:
  #* "MonitoredMounts": an array of strings representing the mount points for which the client should report disk usage
  #  - If omitted, the client will return an empty dictionary for disk usage.
  #* "Timeout": the threshold for a network timeout in seconds
  #  - The default value is 3 seconds.
  #* "Port": the port used for client/server communication
  #  - The default value is 9445.
  #* "Key": the file containing the 128-bit AES encryption key for network transmissions
  #  - The default value is "/etc/stat-monitor/aes128.key".
  #* "PIDFile": the file in which to write the PID
  #  - The default is "/var/run/stat-monitor-client.pid".
  #* "LogFile": the file in which to log errors
  #  - The default is "/var/log/stat-monitor-client.log"
  #* "Debug": a boolean value specifying whether to log debug messages
  #  - The default value is false
  #
  #==Environment variables
  #The configuration values may be influenced by the following environment variables:
  #* +STATMONITOR_ROOT+: used for unit testing:
  #  - When this variable is set, data files will be loaded from a different "root directory."
  #    For example, <tt>"$STATMONITOR_ROOT/proc/cpuinfo"</tt> will be loaded instead of <tt>"/proc/cpuinfo"</tt>.
  #    Setting this to a value other than <tt>"/"</tt> will also change the value of df_command
  #    to <tt>"cat $STATMONITOR_ROOT/df.snapshot"</tt>.
	class Config
    #A Set containing the names of all mount points whose disk space is monitored
  	attr_reader :monitored_mounts
    #The port used for client/server communication
    attr_reader :port
    #The network timeout to be used
  	attr_reader :timeout
    #The directory containing the info files to be read; this is set to the system root directory unless
    #a snapshot is being used for unit testing.
  	attr_reader :root_dir
    #The command to obtain disk usage statistics
  	attr_reader :df_command
    #The file containg memory info
  	attr_reader :meminfo_file
    #The file containing CPU info
  	attr_reader :cpuinfo_file
    #The file containing load averages
  	attr_reader :loadavg_file
    #The file containing UTMP structures for all user processes
  	attr_reader :utmp_file
    #The file containing the encryption key
    attr_reader :key_file
    #The encryption key
    attr_reader :key
    #The location of the PID file
    attr_reader :pid_file
    #The location of the log file
    attr_reader :log_file
    #The Logger object for the log file
    attr_reader :log
    #The syslog object
    attr_reader :syslog
    #The debug status
    attr_reader :debug

    #Initialies the object using the given configuration file
		def initialize(filename)
			#To do: error checking
      file = nil
      config = nil
      begin
        file = File.open(filename, "r")
  			config = JSON.parse(file.read)
      ensure
        file.close unless file.nil?
      end

      @debug = (config['Debug'] == true)

      #This should be done first so future errors can go to the log.
      if config.include?'LogFile'
        @log_file = config['LogFile'].to_s
      else
        @log_file = "/var/log/stat-monitor-client.log"
      end

      @log = Logger.new(@log_file)
      @syslog = Syslog.open($0, Syslog::LOG_PID | Syslog::LOG_CONS)

      if @debug
        @log.level = Logger::DEBUG
        @syslog.mask = Syslog::LOG_UPTO(Syslog::LOG_DEBUG)
      else
        @log.level = Logger::INFO
        @syslog.mask = Syslog::LOG_UPTO(Syslog::LOG_INFO)
      end

	    #To do: make sure all loaded data are the correct type?
	    if config.include?'MonitoredMounts'
	      @monitored_mounts = Set.new(config['MonitoredMounts'])
	    else
	      @monitored_mounts = Set.new
	    end
	    
	    if config.include?'Timeout'
	      @timeout = config['Timeout'].to_f
	    else
	      @timeout = 3
	    end
	    
	    if config.include?'Port'
	    	@port = config['Port'].to_i
	    else
	    	@port = 9445
	    end

      @key_file = config['Key'] || '/etc/stat-monitor/aes128.key'

      if File.file? @key_file
        File.open(@key_file) do |file|
	       @key = file.read[0 .. 15]
         #.chomp!.split("")
         @key = nil unless @key.length == 16
        end
      end

      if config.include?'PIDFile'
        @pid_file = config['PIDFile'].to_s
      else
        @pid_file = '/var/run/stat-monitor-client.pid'
      end

      @root_dir = ENV['STATMONITOR_ROOT'] || '/'
      if @root_dir == '/'
        @df_command = 'df -P | sed 1d'
      else
        @df_command = 'cat "' + File.join(@root_dir, 'df.snapshot') + '"'
      end
  
      @meminfo_file = File.join(@root_dir, 'proc/meminfo')
      @cpuinfo_file = File.join(@root_dir, 'proc/cpuinfo')
      @loadavg_file = File.join(@root_dir, 'proc/loadavg')
      @utmp_file = File.join(@root_dir, 'var/run/utmp')
		end
	end
end