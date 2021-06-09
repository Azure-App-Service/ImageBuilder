require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'

describe "IO::Like#rewind" do
  before :each do
    @file = File.open(File.dirname(__FILE__) + '/fixtures/readlines.txt', 'r')
    @iowrapper = ReadableIOWrapper.open(@file)
  end

  after :each do
    @iowrapper.close unless @iowrapper.closed?
    @file.close unless @file.closed?
  end

  it "should return 0" do
    @iowrapper.rewind.should == 0
  end

  it "positions the instance to the beginning of input" do
    @iowrapper.readline.should == "Voici la ligne une.\n"
    @iowrapper.readline.should == "Qui è la linea due.\n"
    @iowrapper.rewind
    @iowrapper.readline.should == "Voici la ligne une.\n"
  end

  it "positions the instance to the beginning of input and clears EOF" do
    value = @iowrapper.read
    @iowrapper.rewind
    @iowrapper.eof?.should == false
    value.should == @iowrapper.read
  end

  it "sets lineno to 0" do
    @iowrapper.readline.should == "Voici la ligne une.\n"
    @iowrapper.lineno.should == 1
    @iowrapper.rewind
    @iowrapper.lineno.should == 0
  end

  it "works on write-only streams" do
    file = tmp('IO_Like__rewind.test')
    File.open(file, 'w') do |f|
      WritableIOWrapper.open(f) do |io|
        io.write('test1')
        io.rewind.should == 0
        io.write('test2')
      end
    end
    File.read(file).should == 'test2'
    File.delete(file)
  end

  it "raises IOError on closed stream" do
    lambda { IOSpecs.closed_file.rewind }.should raise_error(IOError)
  end
end
