require 'spec_helper'

describe StatMonitor do
  before(:all) do
  
  end
  
  it "correctly encrypts and decrypts data" do
    encrypted = StatMonitor::aes_128_cbc_encrypt("abcd", @config.key)
    StatMonitor::aes_128_cbc_decrypt(encrypted, @config.key).should eql "abcd"
  end
  
  it "throws on improperly formatted messages" do
    expect { StatMonitor::aes_128_cbc_decrypt("not really encrypted", @config.key) }.to raise_error
  end
end