require 'json'

require 'spec_helper'

describe StatMonitor::LocalStats do
  before(:all) do
    @CORRECT_HASH = {"Disks"=>{"/boot"=>9, "/"=>9}, "Message"=>"OK", "Status"=>0, "Processors"=>1, "Memory"=>{"SwapCached"=>0, "SwapFree"=>100, "Total"=>1020696, "Cached"=>173688, "SwapTotal"=>2064376, "Free"=>72}, "Users"=>["vagrant"], "Load"=>[0, 0, 0]}
    @MESSAGE_TOO_SHORT_HASH = {'Status' => 2, 'Message' => 'Invalid message length'}
    @BAD_CHECKSUM_HASH  = {'Status' => 3, 'Message' => 'Invalid checksum'}
    @BAD_TIMESTAMP_HASH = {'Status' => 4, 'Message' => 'Timestamp does not match local time'}
    ENV['STATMONITOR_ROOT'] = File.join(Dir.pwd, 'snapshot/')

    @config = StatMonitor::Config.new("snapshot/client.rc")

    encrypted = StatMonitor::aes_128_cbc_encrypt(Time.new.to_i.to_s, @config.key)
    encrypted_invalid = StatMonitor::aes_128_cbc_encrypt((Time.new.to_i - 30 * 60).to_s, @config.key)
    checksum = Digest::MD5.digest(encrypted)
    checksum_invalid = Digest::MD5.digest(encrypted_invalid)
    @message = Base64.encode64(checksum + encrypted).gsub(/\n/, "")
    @message_invalid = Base64.encode64(checksum_invalid + encrypted_invalid).gsub(/\n/, "")

    @stats = StatMonitor::LocalStats.new(@config)

    @client = StatMonitor::Client.new(@config)
  end

  it "Generates correct data" do
    puts(Dir.pwd)
    @stats.get().should eql @CORRECT_HASH
  end

  #To do: restore? (needs rewriting for new protocol)

  # it "Properly returns data over the network" do
  #   testMsg(@message, @config).should eql @CORRECT_HASH
  # end

  it "Properly handles empty or too-short messages" do
    @client.process_message("").should eql @MESSAGE_TOO_SHORT_HASH
    @client.process_message("test").should eql @MESSAGE_TOO_SHORT_HASH
  end

  it "Properly handles messages with invalid checksums" do
    msg = Base64.encode64("This messsage has a bad checksum!               ")
    @client.process_message(msg).should eql @BAD_CHECKSUM_HASH
  end

  it "Properly handles messages with invalid timestamps" do
    @client.process_message(@message_invalid).should eql @BAD_TIMESTAMP_HASH
  end
end

