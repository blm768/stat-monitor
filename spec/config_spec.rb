require 'spec_helper'

describe StatMonitor::Config do
  it "opens logs" do
    @config.log.should_not be_nil
    @config.syslog.should_not be_nil
  end
  it "creates proper defaults" do
    StatMonitor::Config.any_instance.stubs(:open_logs).returns(nil).never
    dconfig = StatMonitor::Config.new('snapshot/default.rc')
    dconfig.monitored_mounts.should eql Set.new
    dconfig.port.should eql 9445
    dconfig.timeout.should eql 3
  end
end