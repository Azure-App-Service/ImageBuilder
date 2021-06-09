require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'

describe "IO::Like#sysread on a file" do
  before :each do
    @filename = tmp("IO_Like___sysread_file") + $$.to_s
    @contents = "012345678901234567890123456789"
    File.open(@filename, "w") { |f| f.write(@contents) }

    @file = File.open(@filename, "r+")
    @iowrapper = IOWrapper.open(@file)
  end

  after :each do
    @iowrapper.close unless @iowrapper.closed?
    @file.close unless @file.closed?
    File.delete(@filename) if File.exists?(@filename)
  end

  it "reads the specified number of bytes from the file" do
    @iowrapper.sysread(15).should == @contents.slice(0, 15)
  end

  it "reads the specified number of bytes from the file to the buffer" do
    buf = "" # empty buffer
    @iowrapper.sysread(15, buf).should == buf
    buf.should == @contents.slice(0, 15)

    @iowrapper.rewind

    buf = "ABCDE" # small buffer
    @iowrapper.sysread(15, buf).should == buf
    buf.should == @contents.slice(0, 15)

    @iowrapper.rewind

    buf = "ABCDE" * 5 # large buffer
    @iowrapper.sysread(15, buf).should == buf
    buf.should == @contents.slice(0, 15)
  end

  it "coerces the second argument to string and uses it as a buffer" do
    buf = "ABCDE"
    (obj = mock("buff")).should_receive(:to_str).and_return(buf)
    @iowrapper.sysread(15, obj).should == buf
    buf.should == @contents.slice(0, 15)
  end

  it "advances the position of the file by the specified number of bytes" do
    @iowrapper.sysread(15)
    @iowrapper.sysread(5).should == @contents.slice(15, 5)
  end

  it "raises IOError when called immediately after a buffered IO#read" do
    @iowrapper.read(15)
    lambda { @iowrapper.sysread(5) }.should raise_error(IOError)
  end

  it "does not raise IOError if called after IO#read followed by IO#write" do
    @iowrapper.read(5)
    @iowrapper.write("abcde")
    lambda { @iowrapper.sysread(5) }.should_not raise_error(IOError)
  end

  it "does not raise IOError if called after IO#read followed by IO#syswrite" do
    @iowrapper.read(5)
    @iowrapper.syswrite("abcde")
    lambda { @iowrapper.sysread(5) }.should_not raise_error(IOError)
  end

  it "reads updated content after the flushed buffered IO#write" do
    @iowrapper.write("abcde")
    @iowrapper.flush
    @iowrapper.sysread(5).should == @contents.slice(5, 5)
    File.open(@filename) do |f|
      f.sysread(10).should == "abcde56789"
    end
  end

  it "raises IOError on write-only stream" do
    lambda { IOSpecs.writable_iowrapper.sysread(5) }.should raise_error(IOError)
  end

  it "raises IOError on closed stream" do
    lambda { IOSpecs.closed_file.sysread(5) }.should raise_error(IOError)
  end
end
