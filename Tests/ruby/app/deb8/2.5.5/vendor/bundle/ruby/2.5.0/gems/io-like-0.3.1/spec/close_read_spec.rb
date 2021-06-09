require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'
require 'fileutils'

describe "IO::Like#close_read" do
  before :each do
    @io = IO.popen('cat', "r+")
    @iowrapper = DuplexedIOWrapper.open(@io)
    @filename = tmp('IO_Like__close_read_test')
  end

  after :each do
    @iowrapper.close unless @iowrapper.closed?
    @io.close unless @io.closed?
    File.delete(@filename) if File.exist?(@filename)
  end

  it "closes the read end of a duplex I/O stream" do
    @iowrapper.close_read

    lambda { @iowrapper.read }.should raise_error(IOError)
  end

  it "raises an IOError on subsequent invocations" do
    @iowrapper.close_read

    lambda { @iowrapper.close_read }.should raise_error(IOError)
  end

  it "allows subsequent invocation of close" do
    @iowrapper.close_read

    lambda { @iowrapper.close }.should_not raise_error
  end

  it "raises an IOError if the stream is writable and not duplexed" do
    io = File.open(@filename, 'w')
    iowrapper = WritableIOWrapper.open(io)

    begin
      lambda { iowrapper.close_read }.should raise_error(IOError)
    ensure
      iowrapper.close unless iowrapper.closed?
      io.close unless io.closed?
    end
  end

  it "closes the stream if it is neither writable nor duplexed" do
    FileUtils.touch(@filename)
    io = File.open(@filename)
    iowrapper = ReadableIOWrapper.open(io)

    iowrapper.close_read
    iowrapper.closed?.should == true

    io.close
  end

  it "raises IOError on closed stream" do
    @io.close

    lambda { @io.close_read }.should raise_error(IOError)
  end
end
