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
  #* "PublicKey": the file containing the public encryption key
  #  - The default value is "/etc/stat-monitor/public_key.pem".
  #* "PIDFile": the file in which to write the PID
  #  - The default is "/var/run/stat-monitor-client.pid".
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
    #The file holding the public key for decrypting connection data
    attr_reader :public_key_file
    #The file holding the private key for encrypting connection data
    attr_reader :private_key_file
    #The location of the PID file
    attr_reader :pid_file

    #Initialies the object using the given configuration file
		def initialize(filename)
			#To do: error checking
      file = File.open(filename, "r")
			config = JSON.parse(file.read)

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

	    if config.include?'PublicKey'
	    	@public_key_file = config['PublicKey'].to_s
	    else
	    	@public_key_file = '/etc/stat-monitor/public_key.pem'
	    end

      if config.include?'PrivateKey'
        @private_key_file = config['PrivateKey'].to_s
      else
        @private_key_file = '/etc/stat-monitor/private_key.pem'
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