require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'

describe "IO::Like#binmode" do
  before :each do
    @filename = tmp("IO_binmode_file")
    @file = File.open(@filename, "w")
    @iowrapper = WritableIOWrapper.open(@file)
  end

  after :each do
    @iowrapper.close unless @iowrapper.closed?
    @file.close unless @file.closed?
    File.delete(@filename) if File.exist?(@filename)
  end

  it "returns a reference to the stream" do
    @iowrapper.binmode.should == @iowrapper
  end

  it "does not raise any errors on closed stream" do
    lambda { IOSpecs.closed_file.binmode }.should_not raise_error()
  end

  # Even if it does nothing in Unix it should not raise any errors.
  it "puts a stream in binary mode" do
    lambda { @iowrapper.binmode }.should_not raise_error
  end
end
