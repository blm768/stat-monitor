module StatMonitor
	class Config
	attr_reader :monitored_mounts
	attr_reader :timeout
	attr_reader :root_dir
	attr_reader :df_command
	attr_reader :meminfo_file
	attr_reader :cpuinfo_file
	attr_reader :loadavg_file
	attr_reader :utmp_file

		def initialize(filename)
			#To do: error checking
			config = JSON.parse(File.read(filename)) 

	    #To do: make sure all loaded data are the correct type?
	    if config.include?'MonitoredMounts'
	      @monitoredMounts = Set.new(config['MonitoredMounts'])
	    else
	      @monitoredMounts = Set.new
	    end
	    
	    if config.include?'Timeout'
	      @timeout = config['Timeout']
	    else
	      @timeout = 3
	    end
	    
	    if config.include?'Port'
	    	@port = config['Port']
	    else
	    	@port = 9445
	    end

	    if config.include?'PublicKey'
	    	@public_key_file = config['PublicKey']
	    else
	    	@public_key_file = '/etc/stat-monitor-client/public_key.pem'
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