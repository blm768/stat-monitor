require 'json'
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

      cpuData = File.open(@@cpuinfo_file, "r") 
      cpuData.each_line do |line|
        line.chomp!
        num += 1 if /^processor\s*:\s*\d$/ =~ line
      end
      
      cpuData.close
      num
    end

    def self.loadStats()
      loadavg = File.open(@@loadavg_file)
      loads = loadavg.readline.split(' ')[0 ... 3].map{|str| Float(str)}
      loadavg.close
      loads
    end
    
    def self.diskUsage()
      #To do: error values for mount points that are specified but not present?
      return {} if @@monitoredMounts.empty?
      
      #To do: error checking?
      diskData = `#{@@df_command}`
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
      
      File.open(@@meminfo_file) do |file|
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
        'SwapCached' => swapCached}
    end

    def self.get()
        {'Processors' => numProcessors, 'Memory' => memStats, 'Load' => loadStats, 'Disks' => diskUsage, 
          'Users' => Set.new(StatMonitor::Utmp::users(@@utmp_file)).to_a, 'Status' => 0, 'Message' => 'OK'}
    end

    @@config = JSON.parse(File.read("/etc/stat-monitor-client/stat-monitor-client.rc")) 

    #To do: make sure all loaded data are the correct type?
    if @@config.include?'MonitoredMounts'
      @@monitoredMounts = Set.new(@@config['MonitoredMounts'])
    else
      @@monitoredMounts = Set.new
    end
    
    if @@config.include?'Timeout'
      @@timeout = @@config['Timeout']
    else
        timeout = @@config['Timeout']
    end
    
    def self.timeout()
      return @@timeout
    end
    
    #Stuff for unit testing; allows using snapshots of /proc files, etc.
    def self.set_root(root)
      @@root_dir = root
      if root == '/'
        @@df_command = 'df -P | sed 1d'
      else
        @@df_command = 'cat "' + File.join(@@root_dir, 'df.snapshot') + '"'
      end
  
      @@meminfo_file = File.join(@@root_dir, 'proc/meminfo')
      @@cpuinfo_file = File.join(@@root_dir, 'proc/cpuinfo')
      @@loadavg_file = File.join(@@root_dir, 'proc/loadavg')
      @@utmp_file = File.join(@@root_dir, 'var/run/utmp')
    end

    set_root(ENV['STATMONITOR_ROOT'] || '/')

  end
end

