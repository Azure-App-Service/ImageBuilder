require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'

describe "IO::Like#sysseek on a file" do
  # TODO: This should be made more generic with seek spec
  before :each do
    @file = File.open(File.dirname(__FILE__) + '/fixtures/readlines.txt', 'r')
    @iowrapper = IOWrapper.open(@file)
  end

  after :each do
    @iowrapper.close unless @iowrapper.closed?
    @file.close unless @file.closed?
  end

  it "moves the read position relative to the current position with SEEK_CUR" do
    @iowrapper.sysseek(10, IO::SEEK_CUR)
    @iowrapper.readline.should == "igne une.\n"
  end

  it "raises an error when called after buffered reads" do
    @iowrapper.readline
    lambda { @iowrapper.sysseek(-5, IO::SEEK_CUR) }.should raise_error(IOError)
  end

  it "warns if called immediately after a buffered IO#write" do
    begin
      # copy contents to a separate file
      tmpfile = File.open(tmp("tmp_IO_sysseek"), "w")
      wrapper = IOWrapper.open(tmpfile)
      wrapper.write(@iowrapper.read)
      wrapper.seek(0, File::SEEK_SET)

      wrapper.write("abcde")
      lambda { wrapper.sysseek(10) }.should complain(/sysseek/)
    ensure
      wrapper.close
      File.unlink(tmpfile.path)
    end
  end

  it "moves the read position relative to the start with SEEK_SET" do
    @iowrapper.sysseek(42, IO::SEEK_SET)
    @iowrapper.readline.should == "quí está la línea tres.\n"
  end

  it "moves the read position relative to the end with SEEK_END" do
    @iowrapper.sysseek(1, IO::SEEK_END)

    # this is the safest way of checking the EOF when
    # sys-* methods are invoked
    lambda { @iowrapper.sysread(1) }.should raise_error(EOFError)

    @iowrapper.sysseek(-25, IO::SEEK_END)
    @iowrapper.sysread(7).should == "cinco.\n"
  end

  it "can handle any numerical argument without breaking and can seek past EOF" do
    @iowrapper.sysseek(1.2).should == 1
    @iowrapper.sysseek(2**10).should == 1024
    @iowrapper.sysseek(2**32).should == 4294967296
    lambda { @iowrapper.sysseek(2**128) }.should raise_error(RangeError)
  end

  it "raises IOError on closed stream" do
    lambda { IOSpecs.closed_file.sysseek(0) }.should raise_error(IOError)
  end
end
