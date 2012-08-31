module Stats
  class LocalStats

    def self.memStats()
    memTotal = nil
    memFree = nil
    swapTotal = nil
    swapFree = nil
    memCached = nil
    swapCached = nil
    
    File.open("/proc/meminfo") do |file|
      def getValue(line)
        Integer(/\d+/.match(line)[0])
      end
      file.each_line do |line|
        case line
          when /^MemTotal:\s/
            memTotal = getValue(line)
          when /^MemFree:\s/
            memFree = getValue(line)
          when /^SwapTotal:\s/
            swapTotal = getValue(line)
          when /^SwapFree:\s/
            swapFree = /\d+/.match(line)[0]
          when /^Cached\s/
            memCached = /\d+/.match(line[0])
          when /^SwapCached\s/
            swapCached = /\d+/.match(line[0])
        end
      end
    end

    if memFree
      if memTotal
        memFree /= memTotal
      else
        memFree = nil
      end
    end

    if swapFree
      if swapTotal
        swapFree /= swapTotal
      else
        swapFree = nil
      end
    end

    {'Total' => memTotal, 'Free' => memFree, 'SwapTotal' => swapTotal, 'SwapFree' => swapFree, 'Cached' => memCached, 'SwapCached' => swapCached}
  end

  def self.get()
      data = {}

      #Load processor data

      numProcessors = 0

      cpuData = File.open("/proc/cpuinfo", "r") 
      cpuData.each_line do |line|
        line.chomp!
        
        numProcessors += 1 if /^processor\s*:\s*\d$/ =~ line
      end
      
      cpuData.close
      
      users = {}

      #Get user data
      userData = `w`
      #Remove first two lines, which are just column headers.
      userData = userData.to_a[2 .. -1].join

      userData.each_line do |line|
        fields = line.split(/\s+/)
        userName = fields[0]
        users[userName] = {} unless users.include?(userName)
      end
      
      #Return data
      data['processorCount'] = numProcessors
     # data['cpuLoad'] = cpuLoad
      data['users'] = users
      #data['loadStatus'] = loads
      data['memory'] = memStats()

      data
    end
  end

  end

