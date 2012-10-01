require 'spec_helper'

require 'statmonitor/eot_socket_wrapper'

describe StatMonitor::EOTSocketWrapper do
  before(:each) do
    @sock = DummySocket.new
    @wrapper = StatMonitor::EOTSocketWrapper.new(@sock)
    IO.stubs(:select).with([@sock], nil, nil, 3).returns(@wrapper)
  end

  it "correctly locates the first EOT character" do
    @sock.buf = "Testing...\004random_text_goes_here"
    @wrapper.read_until_eot(3).should eql "Testing..."
  end
  it "correctly handles a missing EOT character" do
    @sock.buf = "This will never be returned to the user."
    @wrapper.read_until_eot(3).should eql nil
  end
  it "correctly handles broken-up messages" do
    @sock.buf = "To be cont"
    @wrapper.read_until_eot(3).should eql nil
    @sock.buf = "inued...\004"
    @wrapper.read_until_eot(3).should eql "To be continued..."
  end
  it "correctly handles sequential messages" do
    @sock.buf = "Thing 1\004Thing 2\004"
    @wrapper.read_until_eot(3).should eql "Thing 1"
    @wrapper.read_until_eot(3).should eql "Thing 2"
  end
  it "doesn't swallow failed writes" do
    broken_sock = Socket.new(:INET, :STREAM)
    broken_wrapper = StatMonitor::EOTSocketWrapper.new(broken_sock)
    expect { broken_wrapper.send_message("abc") }.to raise_error
  end
end