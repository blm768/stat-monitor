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
  
  it "writes a correct PID file" do
    begin
      @client.write_pid_and_messages()
      File.read(@config.pid_file).strip.should eql Process.pid.to_s
    ensure
      FileUtils.rm(@config.pid_file) if File.exists?(@config.pid_file)
    end
  end
  
  it "properly encodes messages" do
    encoded = @client.encode_message("abcd")
    StatMonitor::aes_128_cbc_decrypt(Base64.decode64(encoded), @config.key).should eql "abcd"
  end
  
  it "properly handles correct messages" do
    @client.verify_and_generate_data(@message).should eql @CORRECT_HASH
  end

  it "properly handles empty or too-short messages" do
    @client.verify_and_generate_data(nil).should eql @MESSAGE_TOO_SHORT_HASH
    @client.verify_and_generate_data("test").should eql @MESSAGE_TOO_SHORT_HASH
  end

  it "properly handles messages with invalid checksums" do
    msg = Base64.encode64("This messsage has a bad checksum!               ")
    @client.verify_and_generate_data(msg).should eql @BAD_CHECKSUM_HASH
  end

  it "properly handles messages with invalid timestamps" do
    @client.verify_and_generate_data(@message_invalid).should eql @BAD_TIMESTAMP_HASH
  end
end