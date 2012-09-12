require 'json'
require 'rubygems'
require 'set'

require 'statmonitor/config'
require 'statmonitor/utmp'

module StatMonitor
  class LocalStats
    def initialize(config)
      self.config = config
    end

    @config = nil

    def self.getMemStatsValue(line)
      Integer(/\d+/.match(line)[0])
    end

    private_class_method :getMemStatsValue

    def numProcessors()
      num = 0

      cpuData = File.open(config.cpuinfo_file, "r") 
      cpuData.each_line do |line|
        line.chomp!
        num += 1 if /^processor\s*:\s*\d$/ =~ line
      end
      
      cpuData.close
      num
    end

    def loadStats()
      loadavg = File.open(config.loadavg_file)
      loads = loadavg.readline.split(' ')[0 ... 3].map{|str| Float(str)}
      loadavg.close
      loads
    end
    
    def diskUsage()
      #To do: error values for mount points that are specified but not present?
      return {} if config.monitored_mounts.empty?
      
      #To do: error checking?
      diskData = `#{config.df_command}`
      disks = {}
      
      diskData.each_line do |line|
        fields = line.split(' ')
        name = fields[5 .. -1].join
        disks[name] = Float(fields[4][0 .. -2]) if config.monitored_mounts.include? name
      end

      disks
    end

    def memStats()
      memTotal = nil
      memFree = nil
      swapTotal = nil
      swapFree = nil
      memCached = nil
      swapCached = nil
      
      File.open(config.meminfo_file) do |file|
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
          memFree = memFree / memTotal * 100
        else
          memFree = nil
        end
      end

      if swapFree
        if swapTotal
          swapFree = swapFree / swapTotal * 100
        else
          swapFree = nil
        end
      end

      {'Total' => memTotal, 'Free' => memFree, 'SwapTotal' => swapTotal, 'SwapFree' => swapFree, 'Cached' => memCached,
        'SwapCached' => swapCached}
    end

    def get()
        {'Processors' => numProcessors, 'Memory' => memStats, 'Load' => loadStats, 'Disks' => diskUsage, 
          'Users' => Set.new(StatMonitor::Utmp::users(config.utmp_file)).to_a, 'Status' => 0, 'Message' => 'OK'}
    end

  end
end

