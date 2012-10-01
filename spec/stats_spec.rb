require 'spec_helper'

require 'json'

describe StatMonitor::LocalStats do
  before(:each) do
    @stats = StatMonitor::LocalStats.new(@config)
  end

  it "generates correct data" do
    @stats.get().should eql @CORRECT_HASH
  end
  
  it "correctly handles missing memory total fields" do
    @config.expects(:meminfo_file).at_least_once.returns('snapshot/meminfo_incomplete')
    values = @stats.mem_stats()
    values['Free'].should eql nil
    values['SwapFree'].should eql nil
  end
end

