require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'

describe "IO::Like#readline" do
  before :each do
    testfile = File.dirname(__FILE__) + '/fixtures/gets.txt'
    @contents = File.read(testfile)
    @io = File.open(testfile, 'r')
    @iowrapper = IOWrapper.open(@io)
  end

  after :each do
    @iowrapper.close unless @iowrapper.closed?
    @io.close unless @io.closed?
  end

  it "returns the next line on the stream" do
    @iowrapper.readline.should == "Voici la ligne une.\n"
    @iowrapper.readline.should == "Qui è la linea due.\n"
  end

  it "goes back to first position after a rewind" do
    @iowrapper.readline.should == "Voici la ligne une.\n"
    @iowrapper.rewind
    @iowrapper.readline.should == "Voici la ligne une.\n"
  end

  it "is modified by the cursor position" do
    @iowrapper.seek(1)
    @iowrapper.readline.should == "oici la ligne une.\n"
  end

  it "reads and returns all data available before a SystemCallError is raised when the separator is nil" do
    # Overrride @io.sysread to raise SystemCallError every other time it's
    # called.
    class << @io
      alias :sysread_orig :sysread
      def sysread(length)
        if @error_raised then
          @error_raised = false
          sysread_orig(length)
        else
          @error_raised = true
          raise SystemCallError, 'Test Error'
        end
      end
    end

    lambda { @iowrapper.readline(nil) }.should raise_error(SystemCallError)
    @iowrapper.readline(nil).should == @contents
  end

  it "raises EOFError on end of stream" do
    lambda { loop { @iowrapper.readline } }.should raise_error(EOFError)
  end

  it "raises IOError on closed stream" do
    lambda { IOSpecs.closed_file.readline }.should raise_error(IOError)
  end
end
