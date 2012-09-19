require 'json'

require 'spec_helper'

describe StatMonitor::LocalStats do
  before(:all) do
    ENV['STATMONITOR_ROOT'] = File.join(Dir.pwd, 'snapshot/')

    @CORRECT_HASH = {"Disks"=>{"/boot"=>9, "/"=>9}, "Message"=>"OK", "Status"=>0, "Processors"=>1, "Memory"=>{"SwapCached"=>0, "SwapFree"=>100, "Total"=>1020696, "Cached"=>173688, "SwapTotal"=>2064376, "Free"=>72}, "Users"=>["vagrant"], "Load"=>[0, 0, 0]}
    @MESSAGE_TOO_SHORT_HASH = {'Status' => 1, 'Message' => 'Invalid message length'}
    @BAD_CHECKSUM_HASH  = {'Status' => 2, 'Message' => 'Invalid checksum'}
    @BAD_TIMESTAMP_HASH = {'Status' => 3, 'Message' => 'Timestamp does not match local time'}


    privateKey = OpenSSL::PKey::RSA.new(File.read('snapshot/private_key.pem'))

    encrypted = privateKey.private_encrypt(Time.new.to_i.to_s)
    encrypted_invalid = privateKey.private_encrypt((Time.new.to_i - 30 * 60).to_s)
    checksum = Digest::MD5.digest(encrypted)
    checksum_invalid = Digest::MD5.digest(encrypted_invalid)
    @message = Base64.encode64(checksum + encrypted).gsub(/\n/, "")
    @message_invalid = Base64.encode64(checksum_invalid + encrypted_invalid).gsub(/\n/, "")

    @config = StatMonitor::Config.new("snapshot/client.rc")

    @stats = StatMonitor::LocalStats.new(@config)

    @client = StatMonitor::Client.new(@config)

    @remote_client = fork do
      client = StatMonitor::Client.new(@config)
      client.run()
    end
    sleep(1)
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
    @client.process_message("This messsage has a bad checksum!").should eql @BAD_CHECKSUM_HASH
  end

  it "Properly handles messages with invalid timestamps" do
    @client.process_message(@message_invalid).should eql @BAD_TIMESTAMP_HASH
  end

  after(:all) do
    Process.kill('STOP', @remote_client)
  end
end

