module Stats
  class LocalStats
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

      #Get load data
      topData = `top -b -n 1`
      
      memory = {}
      loads = nil
      cpuLoad = nil

      topData.each_line do |line|
        case line
          when /^top\s/
            #To do: error checking?
            loads = line.split("load average:")[1].split(", ").map{|str| Float(str.chomp)}
          when /^Cpu\(s\)\s/
            cpuLoadStats = line.split(":")[1].split(",")[0 .. 1].map{|str| Float(/\d+\.\d+/.match(str)[0])}
            cpuLoad = cpuLoadStats[0] + cpuLoadStats[1]
          when /^Mem:\s/
            physMemStats = line.split(":")[1]
        end
      end
      #Return data
      data['processorCount'] = numProcessors
      data['cpuLoad'] = cpuLoad
      data['users'] = users
      data['loadStatus'] = loads

      data
    end
  end
end

