module Stats
  class LocalStats
    def self.get()
      data = {}

      #Load processor data
      data['processors'] = []
      cpuData = File.open("/proc/cpuinfo", "r") 
      cpuData.each_line do |line|
        puts line
        line.chomp!
        case line
          when /^processor\s*/
            begin
              puts Integer(/\d+/.match(line).captures[0]).to_s
            recover
              #
            end
        end
      end
    end
  end
end

