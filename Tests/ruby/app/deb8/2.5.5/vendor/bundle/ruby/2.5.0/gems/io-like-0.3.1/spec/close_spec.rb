require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'

describe "IO::Like#close" do
  before :each do
    @filename = tmp('IO_Like__close_test')
    @io = File.open(@filename, 'w+')
    @iowrapper = IOWrapper.open(@io)
  end

  after :each do
    @iowrapper.close unless @iowrapper.closed?
    @io.close unless @io.closed?
    File.unlink(@filename) if File.exist?(@filename)
  end

  it "closes the stream" do
    lambda { @iowrapper.close }.should_not raise_error
    @iowrapper.closed?.should == true
  end

  it "returns nil" do
    @iowrapper.close.should == nil
  end

  it "makes the stream unavailable for any further data operations" do
    @iowrapper.close
    lambda { @iowrapper.write("attempt to write") }.should raise_error(IOError)
    lambda { @iowrapper.read }.should raise_error(IOError)
  end

  it "raises an IOError on subsequent invocations" do
    @iowrapper.close
    lambda { @iowrapper.close }.should raise_error(IOError)
  end
end
