require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'

describe "IO::Like#getc" do
  before :each do
    @file_name = File.dirname(__FILE__) + '/fixtures/readlines.txt'
    @file = File.open(@file_name, 'r')
    @iowrapper = ReadableIOWrapper.open(@file)
  end

  after :each do
    @iowrapper.close unless @iowrapper.closed?
    @file.close unless @file.closed?
  end

  it "returns the next byte from the stream" do
    @iowrapper.getc.should == 86
    @iowrapper.getc.should == 111
    @iowrapper.getc.should == 105
    # read the rest of line
    @iowrapper.readline.should == "ci la ligne une.\n"
    @iowrapper.getc.should == 81
  end

  it "returns nil when invoked at the end of the stream" do
    # read entire content
    @iowrapper.read
    @iowrapper.getc.should == nil
  end

  it "returns nil on empty stream" do
    path = tmp('empty.txt')
    File.open(path, "w+") do |empty|
      IOWrapper.open(empty) do |iowrapper|
        iowrapper.getc.should == nil
      end
    end
    File.unlink(path)
  end

  it "raises IOError on closed stream" do
    lambda { IOSpecs.closed_file.getc }.should raise_error(IOError)
  end
end
