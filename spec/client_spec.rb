require 'spec_helper'

describe StatMonitor::Client do
  before :all do
    @client = StatMonitor::Client.new(@config)
    
    encrypted = StatMonitor::aes_128_cbc_encrypt(Time.new.to_i.to_s, @config.key)
    encrypted_invalid = StatMonitor::aes_128_cbc_encrypt((Time.new.to_i - 30 * 60).to_s, @config.key)
    checksum = Digest::MD5.digest(encrypted)
    checksum_invalid = Digest::MD5.digest(encrypted_invalid)
    @message = Base64.encode64(checksum + encrypted).gsub(/\n/, "")
    @message_invalid = Base64.encode64(checksum_invalid + encrypted_invalid).gsub(/\n/, "")
  end
  
  #To do: restore? (needs rewriting for new protocol)

  # it "Properly returns data over the network" do
  #   testMsg(@message, @config).should eql @CORRECT_HASH
  # end
  
  it "properly handles correct messages" do
    @client.process_message(@message).should eql @CORRECT_HASH
  end

  it "properly handles empty or too-short messages" do
    @client.process_message(nil).should eql @MESSAGE_TOO_SHORT_HASH
    @client.process_message("test").should eql @MESSAGE_TOO_SHORT_HASH
  end

  it "properly handles messages with invalid checksums" do
    msg = Base64.encode64("This messsage has a bad checksum!               ")
    @client.process_message(msg).should eql @BAD_CHECKSUM_HASH
  end

  it "properly handles messages with invalid timestamps" do
    @client.process_message(@message_invalid).should eql @BAD_TIMESTAMP_HASH
  end
end