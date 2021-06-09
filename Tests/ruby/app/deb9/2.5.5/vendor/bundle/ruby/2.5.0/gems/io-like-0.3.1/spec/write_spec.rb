require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'
require File.dirname(__FILE__) + '/shared/write'

describe "IO::Like#write" do
  before :each do
    @filename = tmp("IO_Like__write_test")
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

  # TODO: impl detail? discuss this with matz. This spec is useless. - rdavis
  it "writes all of the string's bytes but buffers them" do
    written = @iowrapper.write("abcde")
    written.should == 5
    File.open(@filename) do |file|
      file.read.should == "012345678901234567890123456789"
      @iowrapper.flush
      file.rewind
      file.read.should == "abcde5678901234567890123456789"
    end
  end

  it "returns the number of bytes written" do
    @iowrapper.write('').should == 0
    @iowrapper.write('abcde').should == 5
  end

  it "writes all of the string's bytes without buffering if mode is sync" do
    @iowrapper.sync = true
    written = @iowrapper.write("abcde")
    written.should == 5
    File.open(@filename) do |file|
      file.read(10).should == "abcde56789"
    end
  end

  it "does not raise IOError on read-only stream if writing zero bytes" do
    lambda do
      IOSpecs.readable_iowrapper do |iowrapper|
        iowrapper.write("")
      end
    end.should_not raise_error
  end

  it "does not raise IOError on closed stream if writing zero bytes" do
    lambda { IOSpecs.closed_file.write("") }.should_not raise_error
  end
end

describe "IO::Like#write" do
  it_behaves_like :io_like__write, :write
end
