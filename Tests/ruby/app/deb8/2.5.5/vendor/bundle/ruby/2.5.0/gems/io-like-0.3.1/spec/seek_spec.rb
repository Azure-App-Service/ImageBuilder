require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'

describe "IO::Like#seek" do
  before :each do
    @file = File.open(File.dirname(__FILE__) + '/fixtures/readlines.txt', 'r')
    @iowrapper = IOWrapper.open(@file)
  end

  after :each do
    @iowrapper.close unless @iowrapper.closed?
    @file.close unless @file.closed?
  end

  it "moves the read position relative to the current position with SEEK_CUR" do
    lambda { @iowrapper.seek(-1) }.should raise_error(Errno::EINVAL)
    @iowrapper.seek(10, IO::SEEK_CUR)
    @iowrapper.readline.should == "igne une.\n"
    @iowrapper.seek(-5, IO::SEEK_CUR)
    @iowrapper.readline.should == "une.\n"
  end

  it "moves the read position relative to the start with SEEK_SET" do
    @iowrapper.seek(1)
    @iowrapper.pos.should == 1
    @iowrapper.rewind
    @iowrapper.seek(42, IO::SEEK_SET)
    @iowrapper.readline.should == "quí está la línea tres.\n"
    @iowrapper.seek(5, IO::SEEK_SET)
    @iowrapper.readline.should == " la ligne une.\n"
  end

  it "moves the read position relative to the end with SEEK_END" do
    @iowrapper.seek(0, IO::SEEK_END)
    @iowrapper.tell.should == 134
    @iowrapper.seek(-25, IO::SEEK_END)
    @iowrapper.readline.should == "cinco.\n"
  end

  it "can handle any numerical argument without breaking" do
    @iowrapper.seek(1.2).should == 0
    @iowrapper.seek(2**32).should == 0
    @iowrapper.seek(1.23423423432e12).should == 0
    @iowrapper.seek(0.00000000000000000000001).should == 0
    lambda { @iowrapper.seek(2**128) }.should raise_error(RangeError)
  end

  it "raises IOError on closed stream" do
    lambda { IOSpecs.closed_file.seek(0) }.should raise_error(IOError)
  end

  it "moves the read position and clears EOF with SEEK_SET" do
    value = @iowrapper.read
    @iowrapper.seek(0, IO::SEEK_SET)
    @iowrapper.eof?.should == false
    value.should == @iowrapper.read
  end

  it "moves the read position and clears EOF with SEEK_CUR" do
    value = @iowrapper.read
    @iowrapper.seek(-1, IO::SEEK_CUR)
    @iowrapper.eof?.should == false
    value[-1].should == @iowrapper.read[0]
  end

  it "moves the read position and clears EOF with SEEK_END" do
    value = @iowrapper.read
    @iowrapper.seek(-1, IO::SEEK_END)
    @iowrapper.eof?.should == false
    value[-1].should == @iowrapper.read[0]
  end
end
