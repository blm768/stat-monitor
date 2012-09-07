require 'rubygems'
require 'set'

require 'statmonitor/utmp'

module StatMonitor
  class LocalStats

    def self.getValue(line)
      Integer(/\d+/.match(line)[0])
    end

    private_class_method :getValue

    def self.numProcessors()
      num = 0

      cpuData = File.open("/proc/cpuinfo", "r") 
      cpuData.each_line do |line|
        line.chomp!
        num += 1 if /^processor\s*:\s*\d$/ =~ line
      end
      
      cpuData.close
      num
    end

    def self.loadStats()
      loadavg = File.open('/proc/loadavg')
      loads = loadavg.readline.split(' ')[0 ... 3].map{|str| Float(str)}
      loadavg.close
      loads
    end
    
    def self.diskUsage()
      return {} if @@monitoredMounts.empty?
      
      diskData = `df -P | sed 1d`
      disks = {}
      
      diskData.each_line do |line|
        fields = line.split(' ')
        name = fields[5 .. -1].join
        disks[name] = Float(fields[4][0 .. -2]) if @@monitoredMounts.include? name
      end

      disks
    end

    def self.memStats()
      memTotal = nil
      memFree = nil
      swapTotal = nil
      swapFree = nil
      memCached = nil
      swapCached = nil
      
      File.open("/proc/meminfo") do |file|
        file.each_line do |line|
          case line
            when /^MemTotal:\s/
              memTotal = getValue(line)
            when /^MemFree:\s/
              memFree = getValue(line)
            when /^SwapTotal:\s/
              swapTotal = getValue(line)
            when /^SwapFree:\s/
              swapFree = getValue(line)
            when /^Cached:\s/
              memCached = getValue(line)
            when /^SwapCached:\s/
              swapCached = getValue(line)
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
        'SwapCached' => swapCached, 'Users' => Set.new(StatMonitor::Utmp::users).to_a}
    end

    def self.get()
        {'Processors' => numProcessors, 'Memory' => memStats, 'Load' => loadStats, 'Disks' => diskUsage}
    end

    @@config = JSON.parse(File.read("/etc/stat-monitor-client/stat-monitor-client.rc")) 

    #To do: make sure all loaded data are the correct type?
    if @@config.include?'monitoredMounts'
      @@monitoredMounts = Set.new(@@config['monitoredMounts'])
    else
      @@monitoredMounts = Set()
    end
    
  end
  
end

