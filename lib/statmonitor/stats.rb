require 'json'
require 'rubygems'
require 'set'

require 'statmonitor/config'
require 'statmonitor/utmp'

module StatMonitor
  #This class provides methods to obtain useful system statistics on the local machine.
  class LocalStats
    #The config argument should be an instance of StatMonitor::Config.
    def initialize(config)
      @config = config
    end

    #Gets the numeric value from a line in /proc/meminfo; used by mem_stats().
    def get_mem_stats_value(line)
      Integer(/\d+/.match(line)[0])
    end

    private   :get_mem_stats_value

    #Returns the number of processors on the system.
    def num_processors()
      num = 0

      cpuData = File.open(@config.cpuinfo_file, "r") 
      cpuData.each_line do |line|
        line.chomp!
        num += 1 if /^processor\s*:\s*\d$/ =~ line
      end
      
      cpuData.close
      num
    end

    #Returns the 5-, 10-, and 15-minute load averages as an array of 3 floating-point values.
    def load_stats()
      loadavg = File.open(@config.loadavg_file)
      loads = loadavg.readline.split(' ')[0 ... 3].map{|str| Float(str)}
      loadavg.close
      loads
    end
    
    #Returns a hash containing disk space percentages for each monitored mount point
    def disk_usage()
      #To do: error values for mount points that are specified but not present?
      return {} if @config.monitored_mounts.empty?
      
      #To do: error checking?
      diskData = `#{@config.df_command}`
      disks = {}
      
      diskData.each_line do |line|
        fields = line.split(' ')
        name = fields[5 .. -1].join
        disks[name] = Float(fields[4][0 .. -2]) if @config.monitored_mounts.include? name
      end

      disks
    end

    #Returns a hash containing the following elements:
    #
    #* "Total": the total amount of physical memory
    #* "Cached": the amount of cached physical memory
    #* "Free": the amount of free physical memory as a percentage of total physical memory
    #* "Swap": the total amount of swap space
    #* "SwapCached": the amount of cached swap space
    #* "SwapFree": the amount of free swap space as a percentage of total swap space
    def mem_stats()
      memTotal = nil
      memFree = nil
      swapTotal = nil
      swapFree = nil
      memCached = nil
      swapCached = nil
      
      File.open(@config.meminfo_file) do |file|
        file.each_line do |line|
          case line
            when /^MemTotal:\s/
              memTotal = getMemStatsValue(line)
            when /^MemFree:\s/
              memFree = getMemStatsValue(line)
            when /^SwapTotal:\s/
              swapTotal = getMemStatsValue(line)
            when /^SwapFree:\s/
              swapFree = getMemStatsValue(line)
            when /^Cached:\s/
              memCached = getMemStatsValue(line)
            when /^SwapCached:\s/
              swapCached = getMemStatsValue(line)
          end
        end
      end

      if memFree
          if memTotal
          memFree = Integer(Float(memFree) / memTotal * 100)
        else
          memFree = nil
        end
      end

      if swapFree
        if swapTotal
          swapFree = Integer(Float(swapFree) / swapTotal * 100)
        else
          swapFree = nil
        end
      end

      {'Total' => memTotal,
        'Free' => memFree,
        'SwapTotal' => swapTotal,
        'SwapFree' => swapFree,
        'Cached' => memCached,
        'SwapCached' => swapCached}
    end

    #Returns a hash containing all statistics.
    #The format mirrors that of the client's JSON response; see StatMonitor::Client for more details.
    def get()
        {'Processors' => num_processors,
          'Memory' => mem_stats,
          'Load' => load_stats,
          'Disks' => disk_usage, 
          'Users' => Set.new(StatMonitor::Utmp::users(@config.utmp_file)).to_a,
          'Status' => 0,
          'Message' => 'OK'}
    end

  end
end

