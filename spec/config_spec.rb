require 'spec_helper'

describe StatMonitor::Config do
  it "correctly reads configuration files" do
    @config.monitored_mounts.should eql Set.new(['/', '/boot'])
    @config.port.should eql 9445
    @config.timeout.should eql 3.0
    @config.key_file.should eql 'snapshot/aes128.key'
    @config.key.should eql File.read('snapshot/aes128.key')
    @config.root_dir.should eql 'snapshot/'
    @config.df_command.should eql "cat 'snapshot/df.snapshot'"
    @config.meminfo_file.should eql 'snapshot/proc/meminfo'
    @config.cpuinfo_file.should eql 'snapshot/proc/cpuinfo'
    @config.loadavg_file.should eql 'snapshot/proc/loadavg'
    @config.utmp_file.should eql 'snapshot/var/run/utmp'
    @config.pid_file.should eql '/tmp/stat-monitor-client.pid'
    @config.log_file.should eql '/dev/null'
    @config.debug.should eql true
  end
  it "opens logs" do
    @config.log.should_not be_nil
    @config.syslog.should_not be_nil
  end
  it "creates proper defaults" do
    dconfig = nil
    @config.close_logs
    begin
      StatMonitor::Config.any_instance.stubs(:open_logs).returns()
      StatMonitor::Config.any_instance.stubs(:syslog).returns(stub(:"level=" => nil, :"mask=" => nil))
      StatMonitor::Config.any_instance.stubs(:log).returns(stub(:"level=" => nil))
      dconfig = StatMonitor::Config.new('snapshot/default.rc')
      dconfig.monitored_mounts.should eql Set.new
      dconfig.port.should eql 9445
      dconfig.timeout.should eql 3.0
      dconfig.key_file.should eql '/etc/stat-monitor/aes128.key'
      dconfig.root_dir.should eql '/'
      dconfig.df_command.should eql 'df -P | sed 1d'
      dconfig.meminfo_file.should eql '/proc/meminfo'
      dconfig.cpuinfo_file.should eql '/proc/cpuinfo'
      dconfig.loadavg_file.should eql '/proc/loadavg'
      dconfig.utmp_file.should eql '/var/run/utmp'
      dconfig.pid_file.should eql '/var/run/stat-monitor-client.pid'
      dconfig.log_file.should eql '/var/log/stat-monitor-client.log'
      dconfig.debug.should eql false
    ensure
      dconfig.close_logs if dconfig
      @config.open_logs
    end
  end
end