require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'

describe "IO::Like#putc" do
  before :each do
    @filename = tmp('IO_Like__putc_test')
    @file = File.open(@filename, 'w')
    @file.sync = true
    @iowrapper = WritableIOWrapper.open(@file)
    @iowrapper.sync = true
  end

  after :each do
    @iowrapper.close unless @iowrapper.closed?
    @file.close unless @file.closed?
    File.unlink @filename
  end

  it "returns a reference to the object" do
    @iowrapper.putc('a').should == 'a'
    @iowrapper.putc(128).should == 128
  end

  it "writes the first byte of a String" do
    @iowrapper.putc("foo")
    File.read(@filename).should == 'f'
  end

  it "writes the first byte of an object's string representation" do
    (obj = mock('test')).should_receive(:to_int).and_return(261)
    @iowrapper.putc(obj)
    File.read(@filename).should == "\005"
  end

  it "writes Numerics that fit in a C char" do
    @iowrapper.putc(-128)
    @iowrapper.putc(0)
    @iowrapper.putc(255)

    File.read(@filename).should == "\200\000\377"
  end

  it "write the first byte of Numerics that don't fit in a C char" do
    @iowrapper.putc(-129)
    @iowrapper.putc(256)

    File.read(@filename).should == "\177\000"
  end

  it "checks if the stream is writable" do
    lambda { IOSpecs.readable_iowrapper.putc('a') }.should raise_error(IOError)
  end

  it "raises IOError on closed stream" do
    lambda { IOSpecs.closed_file.putc('a') }.should raise_error(IOError)
  end
end
