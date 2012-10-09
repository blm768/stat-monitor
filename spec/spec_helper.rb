if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start
end

require 'mocha_standalone'

require 'statmonitor'

#Used to test the socket wrapper code
class DummySocket
  attr_accessor :buf
  
  def initialize(text = "")
    @buf = text
  end
  
  def readpartial(size)
    return nil unless @buf
    if @buf.length >= size
      result = @buf[0 ... size]
      @buf = @buf[size .. -1]
    else
      result = @buf
      @buf = nil
    end
    return result
  end
end

RSpec.configure do |config|
  config.mock_with(:mocha)
  config.before(:all) do
    @CORRECT_HASH = {"Disks"=>{"/boot"=>9, "/"=>9}, "Message"=>"OK", "Status"=>0, "Processors"=>1, "Memory"=>{"SwapCached"=>0, "SwapFree"=>100, "Total"=>1020696, "Cached"=>173688, "SwapTotal"=>2064376, "Free"=>72}, "Users"=>["vagrant"], "Load"=>[0, 0, 0]}
    @MESSAGE_TOO_SHORT_HASH = {'Status' => 2, 'Message' => 'Invalid message length'}
    @BAD_CHECKSUM_HASH  = {'Status' => 3, 'Message' => 'Invalid checksum'}
    @BAD_TIMESTAMP_HASH = {'Status' => 4, 'Message' => 'Timestamp does not match local time'}
    @INTERNAL_ERROR_HASH = {'Status' => 5, 'Message' => 'Error while obtaining statistics'}
    
    ENV['STATMONITOR_ROOT'] = File.join(Dir.pwd, 'snapshot/')
    @config = StatMonitor::Config.new("snapshot/client.rc")
  end
  
  config.after(:all) do
    @config.close_logs
  end
end