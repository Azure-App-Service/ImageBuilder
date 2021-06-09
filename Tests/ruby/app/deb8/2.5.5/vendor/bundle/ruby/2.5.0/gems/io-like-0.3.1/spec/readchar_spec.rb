require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'

describe "IO::Like#readchar" do
  before :each do
    @file_name = File.dirname(__FILE__) + '/fixtures/readlines.txt'
    @io = File.open(@file_name, 'r')
    @iowrapper = IOWrapper.open(@io)
  end

  after :each do
    @iowrapper.close unless @iowrapper.closed?
    @io.close unless @io.closed?
  end

  it "returns the next byte from the stream" do
    @io.readchar.should == 86
    @io.readchar.should == 111
    @io.readchar.should == 105
    # read the rest of line
    @io.readline.should == "ci la ligne une.\n"
    @io.readchar.should == 81
  end

  it "raises EOFError when invoked at the end of the stream" do
    # read entire content
    @io.read
    lambda { @io.readchar }.should raise_error(EOFError)
  end

  it "raises EOFError when reaches the end of the stream" do
    lambda { loop { @io.readchar } }.should raise_error(EOFError)
  end

  it "raises EOFError on empty stream" do
    path = tmp('empty.txt')
    File.open(path, "w+") do |empty|
      IOWrapper.open(empty) do |iowrapper|
        lambda { iowrapper.readchar }.should raise_error(EOFError)
      end
    end

    File.unlink(path)
  end

  it "raises IOError on closed stream" do
    lambda { IOSpecs.closed_file.readchar }.should raise_error(IOError)
  end
end
