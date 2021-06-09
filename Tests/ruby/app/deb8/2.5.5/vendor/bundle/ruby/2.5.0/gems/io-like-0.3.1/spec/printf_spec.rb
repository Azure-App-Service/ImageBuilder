require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'

describe "IO::Like#printf" do
  before :each do
    @io = IO.new(STDOUT.fileno, 'w')
    @iowrapper = WritableIOWrapper.open(@io)
    @iowrapper.sync = true
  end

  after :each do
    @iowrapper.close unless @iowrapper.closed?
  end

  it "writes the #sprintf formatted string to the file descriptor" do
    lambda do
      @io.printf("%s\n", "look ma, no hands")
    end.should output_to_fd("look ma, no hands\n", @io)
  end

  it "raises IOError on closed stream" do
    lambda { IOSpecs.closed_file.printf("stuff") }.should raise_error(IOError)
  end
end
