require 'json'

require 'spec_helper'

CORRECT_HASH = {"Load"=>[0.0, 0.0, 0.0], "Disks"=>{"/"=>9.0, "/boot"=>9.0}, "Users"=>["vagrant"], "Memory"=>{"SwapFree"=>100, "Total"=>1020696, "Cached"=>173688, "SwapTotal"=>2064376, "Free"=>0, "SwapCached"=>0}, "Processors"=>1, 'Status' => 0, 'Message' => 'OK'}

privateKey = OpenSSL::PKey::RSA.new(File.read('/etc/stat-monitor-client/private_key.pem'))

encrypted = privateKey.private_encrypt(Time.new.to_i.to_s)
checksum = Digest::MD5.digest(encrypted)
message = Base64.encode64(checksum + encrypted).gsub(/\n/, "")


def testMsg(msg)
  socket = TCPSocket.open('127.0.0.1', 9445)
  socket.puts(msg)

  gotMessage = IO.select([socket], nil, nil, 3)

  return JSON.parse(socket.gets) if gotMessage

  nil
end

describe StatMonitor::LocalStats do
  it "Generates correct data" do
    puts(Dir.pwd)
    StatMonitor::LocalStats.set_root(File.join(Dir.pwd, 'test'))
    StatMonitor::LocalStats.get().should eql CORRECT_HASH
  end


  ENV['STATMONITOR_ROOT'] = File.join(Dir.pwd, 'test/')
  #client = fork || exec('stat-monitor-client')
  sleep(2)
  begin
    it "Properly returns data over the network" do
          
      testMsg(message).should eql CORRECT_HASH
    end

    it "Properly handles empty or too-short messages" do
      #test
    end
  rescue
    #Process.kill('STOP', client)
    raise $!
  end
  #Process.kill('STOP', client)
end

