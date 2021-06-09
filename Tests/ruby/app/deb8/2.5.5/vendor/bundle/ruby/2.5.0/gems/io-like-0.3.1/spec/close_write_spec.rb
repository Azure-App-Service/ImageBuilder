require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'

describe "IO::Like#close_write" do
  before :each do
    @io = IO.popen('cat', 'r+')
    @iowrapper = DuplexedIOWrapper.open(@io)
    @filename = tmp('IO_Like__close_write_test')
  end

  after :each do
    @iowrapper.close unless @iowrapper.closed?
    @io.close unless @io.closed?
    File.delete(@filename) if File.exist?(@filename)
  end

  it "closes the write end of a duplex I/O stream" do
    @iowrapper.close_write
    lambda { @iowrapper.write("attempt to write") }.should raise_error(IOError)
  end

  it "raises an IOError on subsequent invocations" do
    @iowrapper.close_write
    lambda { @iowrapper.close_write }.should raise_error(IOError)
  end

  it "allows subsequent invocation of close" do
    @iowrapper.close_write
    lambda { @iowrapper.close }.should_not raise_error
  end

  it "raises an IOError if the stream is readable and not duplexed" do
    io = File.open(@filename, 'w+')
    iowrapper = IOWrapper.open(io)

    begin
      lambda { iowrapper.close_write }.should raise_error(IOError)
    ensure
      iowrapper.close unless iowrapper.closed?
      io.close unless io.closed?
    end
  end

  it "closes the stream if it is neither readable nor duplexed" do
    IOSpecs.writable_iowrapper do |iowrapper|
      iowrapper.close_write
      iowrapper.closed?.should == true
    end
  end

  it "flushes and closes the write stream" do
    @iowrapper.puts('12345')
    @iowrapper.close_write
    @io.close_write
    @iowrapper.read.should == "12345\n"
  end

  it "raises IOError on closed stream" do
    lambda { IOSpecs.closed_file.close_write }.should raise_error(IOError)
  end
end
