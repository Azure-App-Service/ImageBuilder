require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'
require File.dirname(__FILE__) + '/shared/write'

describe "IO::Like#syswrite" do
  before :each do
    @filename = tmp("IO_Like__syswrite_test")
    @content = "012345678901234567890123456789"
    File.open(@filename, "w") { |f| f.syswrite(@content) }
    @file = File.open(@filename, "r+")
    @iowrapper = IOWrapper.open(@file)
  end

  after :each do
    @iowrapper.close unless @iowrapper.closed?
    @file.close unless @file.closed?
    File.delete(@filename)
  end

  it "returns the number of bytes written" do
    @iowrapper.syswrite('').should == 0
    @iowrapper.syswrite('abcde').should == 5
  end

  it "writes all of the string's bytes but does not buffer them" do
    written = @iowrapper.syswrite("abcde")
    written.should == 5
    File.open(@filename) do |file|
      file.sysread(10).should == "abcde56789"
      file.seek(0)
      @iowrapper.flush
      file.sysread(10).should == "abcde56789"
    end
  end

  not_compliant_on :rubinius do
    it "warns if called immediately after a buffered IO#write" do
      @iowrapper.write("abcde")
      lambda { @iowrapper.syswrite("fghij") }.should complain(/syswrite/)
    end
  end

  it "does not warn if called after IO#write with intervening IO#sysread" do
    @iowrapper.write("abcde")
    @iowrapper.sysread(5)
    lambda { @iowrapper.syswrite("fghij") }.should_not complain
  end

  it "writes to the actual file position when called after buffered IO#read" do
    @iowrapper.read(5)
    @iowrapper.syswrite("abcde")
    File.open(@filename) do |file|
      file.sysread(10).should == "01234abcde"
    end
  end
end

describe "IO::Like#syswrite" do
  it_behaves_like :io_like__write, :syswrite
end
