require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'

describe "IO::Like#readpartial" do
  before :each do
    @rd, @wr = IO.pipe
    @iowrapper_rd, @iowrapper_wr = IOWrapper.open(@rd), IOWrapper.open(@wr)
    @iowrapper_wr.sync = true
  end

  after :each do
    @iowrapper_rd.close unless @iowrapper_rd.closed?
    @iowrapper_wr.close unless @iowrapper_wr.closed?
    @rd.close unless @rd.closed?
    @wr.close unless @wr.closed?
  end

  it "raises IOError on closed stream" do
    lambda { IOSpecs.closed_file.readpartial(10) }.should raise_error(IOError)

    @iowrapper_rd.close
    lambda { @iowrapper_rd.readpartial(10) }.should raise_error(IOError)
  end

  it "reads at most the specified number of bytes" do
    @iowrapper_wr.write("foobar")

    # buffered read
    @iowrapper_rd.read(1).should == 'f'
    # return only specified number, not the whole buffer
    @iowrapper_rd.readpartial(1).should == "o"
  end

  it "reads after ungetc with data in the buffer" do
    @iowrapper_wr.write("foobar")
    c = @iowrapper_rd.getc
    @iowrapper_rd.ungetc(c)
    @iowrapper_rd.readpartial(3).should == "foo"
    @iowrapper_rd.readpartial(3).should == "bar"
  end

  it "reads after ungetc without data in the buffer" do
    @iowrapper_wr.write("f")
    c = @iowrapper_rd.getc
    @iowrapper_rd.ungetc(c)
    @iowrapper_rd.readpartial(2).should == "f"

    # now, also check that the ungot char is cleared and
    # not returned again
    @iowrapper_wr.write("b")
    @iowrapper_rd.readpartial(2).should == "b"
  end

  it "discards the existing buffer content upon successful read" do
    buffer = "existing"
    @iowrapper_wr.write("hello world")
    @iowrapper_wr.close
    @wr.close
    @iowrapper_rd.readpartial(11, buffer)
    buffer.should == "hello world"
  end

  it "raises EOFError on EOF" do
    @iowrapper_wr.write("abc")
    @iowrapper_wr.close
    @wr.close
    @iowrapper_rd.readpartial(10).should == 'abc'
    lambda { @iowrapper_rd.readpartial(10) }.should raise_error(EOFError)
  end

  it "discards the existing buffer content upon error" do
    buffer = 'hello'
    @iowrapper_wr.close
    @wr.close
    lambda { @iowrapper_rd.readpartial(1, buffer) }.should raise_error(EOFError)
    buffer.should be_empty
  end

  it "raises IOError if the stream is closed" do
    @iowrapper_wr.close
    @wr.close
    lambda { @iowrapper_rd.readpartial(1) }.should raise_error(IOError)
  end

  it "raises ArgumentError if the negative argument is provided" do
    lambda { @iowrapper_rd.readpartial(-1) }.should raise_error(ArgumentError)
  end

  it "immediately returns an empty string if the length argument is 0" do
    @iowrapper_rd.readpartial(0).should == ""
  end
end
