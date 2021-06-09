require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'

describe "IO::Like#sync=" do
  before :each do
    @file = File.dirname(__FILE__) + '/fixtures/readlines.txt'
    @f = File.open(@file)
    @iowrapper = ReadableIOWrapper.open(@f)
  end

  after :each do
    @iowrapper.close unless @iowrapper.closed?
    @f.close unless @f.closed?
  end

  it "sets the sync mode to true or false" do
    @iowrapper.sync = true
    @iowrapper.sync.should == true
    @iowrapper.sync = false
    @iowrapper.sync.should == false
  end

  it "accepts non-boolean arguments" do
    @iowrapper.sync = 10
    @iowrapper.sync.should == true
    @iowrapper.sync = nil
    @iowrapper.sync.should == false
    @iowrapper.sync = Object.new
    @iowrapper.sync.should == true
  end

  it "raises IOError on closed stream" do
    lambda { IOSpecs.closed_file.sync = true }.should raise_error(IOError)
  end
end

describe "IO::Like#sync" do
  before :each do
    @file = File.dirname(__FILE__) + '/fixtures/readlines.txt'
    @f = File.open(@file)
    @iowrapper = ReadableIOWrapper.open(@f)
  end

  after :each do
    @iowrapper.close unless @iowrapper.closed?
    @f.close unless @f.closed?
  end

  it "returns the current sync mode" do
    @iowrapper.sync.should == false
  end

  it "raises IOError on closed stream" do
    lambda { IOSpecs.closed_file.sync }.should raise_error(IOError)
  end
end
