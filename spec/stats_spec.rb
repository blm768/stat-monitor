require 'spec_helper'

require 'json'

describe StatMonitor::LocalStats do
  before(:each) do
    @stats = StatMonitor::LocalStats.new(@config)
  end

  it "Generates correct data" do
    @stats.get().should eql @CORRECT_HASH
  end
end

