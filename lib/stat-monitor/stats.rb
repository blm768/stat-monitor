module Stats
  class LocalStats
    def self.get()
     cpuData = File.open("/proc/cpuinfo", "r") 
     cpuData.each_line do |line|

     end
    end
  end
end

