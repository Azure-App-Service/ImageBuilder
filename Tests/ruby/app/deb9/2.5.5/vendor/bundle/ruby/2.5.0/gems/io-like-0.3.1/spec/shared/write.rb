require File.dirname(__FILE__) + '/../fixtures/classes'

describe :io_like__write, :shared => true do
  before :each do
    @filename = tmp("IO_Like__shared_write_test")
    @content = "012345678901234567890123456789"
    File.open(@filename, "w") { |f| f.write(@content) }
    @file = File.open(@filename, "r+")
    @iowrapper = IOWrapper.open(@file)
  end

  after :each do
    @iowrapper.close unless @iowrapper.closed?
    @file.close unless @file.closed?
    File.delete(@filename)
  end

  it "coerces the argument to a string using to_s" do
    (obj = mock('test')).should_receive(:to_s).and_return('a string')
    @iowrapper.send(@method, obj)
  end

  it "does not warn if called after IO#read" do
    @iowrapper.read(5)
    lambda { @iowrapper.send(@method, "fghij") }.should_not complain
  end

  it "writes to the current position after IO#read" do
    @iowrapper.read(5)
    @iowrapper.send(@method, "abcd")
    @iowrapper.rewind
    @iowrapper.read.should == "01234abcd901234567890123456789"
  end

  it "advances the file position by the count of given bytes" do
    @iowrapper.send(@method, "abcde")
    @iowrapper.read(10).should == "5678901234"
  end

  it "raises IOError on read-only stream if writing more than zero bytes" do
    lambda do
      IOSpecs.readable_iowrapper do |iowrapper|
        iowrapper.send(@method, "abcde")
      end
    end.should raise_error(IOError)
  end

  it "raises IOError on closed stream if writing more than zero bytes" do
    lambda do
      IOSpecs.closed_file.send(@method, "abcde")
    end.should raise_error(IOError)
  end
end
