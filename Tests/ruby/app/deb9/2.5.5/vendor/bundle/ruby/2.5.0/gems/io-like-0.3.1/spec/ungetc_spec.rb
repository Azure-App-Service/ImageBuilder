require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'

describe "IO::Like#ungetc" do
  before :each do
    @file_name = File.dirname(__FILE__) + '/fixtures/readlines.txt'
    @file = File.open(@file_name, 'r')
    @iowrapper = ReadableIOWrapper.open(@file)
  end

  after :each do
    @iowrapper.close unless @iowrapper.closed?
    @file.close unless @file.closed?
  end

  it "pushes back one character onto stream" do
    @iowrapper.getc.should == 86
    @iowrapper.ungetc(86)
    @iowrapper.getc.should == 86

    @iowrapper.ungetc(10)
    @iowrapper.getc.should == 10

    @iowrapper.getc.should == 111
    @iowrapper.getc.should == 105
    # read the rest of line
    @iowrapper.readline.should == "ci la ligne une.\n"
    @iowrapper.getc.should == 81
    @iowrapper.ungetc(99)
    @iowrapper.getc.should == 99
  end

  it "pushes back one character when invoked at the end of the stream" do
    # read entire content
    @iowrapper.read
    @iowrapper.ungetc(100)
    @iowrapper.getc.should == 100
  end

  it "pushes back one character when invoked at the start of the stream" do
    @iowrapper.read(0)
    @iowrapper.ungetc(100)
    @iowrapper.getc.should == 100
  end

  it "pushes back one character when invoked on empty stream" do
    path = tmp('empty.txt')
    File.open(path, "w+") do |empty|
      IOWrapper.open(empty) do |iowrapper|
        iowrapper.getc().should == nil
        iowrapper.ungetc(10)
        iowrapper.getc.should == 10
      end
    end
    File.unlink(path)
  end

  it "affects EOF state" do
    path = tmp('empty.txt')
    File.open(path, "w+") do |empty|
      IOWrapper.open(empty) do |iowrapper|
        iowrapper.eof?.should == true
        iowrapper.getc.should == nil
        iowrapper.ungetc(100)
        iowrapper.eof?.should == false
      end
    end
    File.unlink(path)
  end

  it "adjusts the stream position" do
    @iowrapper.pos.should == 0

    # read one char
    c = @iowrapper.getc
    @iowrapper.pos.should == 1
    @iowrapper.ungetc(c)
    @iowrapper.pos.should == 0

    # read all
    @iowrapper.read
    pos = @iowrapper.pos
    @iowrapper.ungetc(98)
    @iowrapper.pos.should == pos - 1
  end

  # TODO: file MRI bug
  # Another specified behavior that MRI doesn't follow:
  # "Has no effect with unbuffered reads (such as IO#sysread)."
  #
  #it "has no effect with unbuffered reads" do
  #  length = File.size(@file_name)
  #  content = @iowrapper.sysread(length)
  #  @iowrapper.rewind
  #  @iowrapper.ungetc(100)
  #  @iowrapper.sysread(length).should == content
  #end

  it "makes subsequent unbuffered operations to raise IOError" do
    @iowrapper.getc
    @iowrapper.ungetc(100)
    lambda { @iowrapper.sysread(1) }.should raise_error(IOError)
  end

  # WORKS AS DESIGNED:
  # Since IO::Like has complete control over the read buffer, it supports
  # pushing unlimited data into that buffer at any time on any readable stream.
  #
  #it "raises IOError when invoked on stream that was not yet read" do
  #  lambda { @iowrapper.ungetc(100) }.should raise_error(IOError)
  #end

  it "raises IOError on closed stream" do
    @iowrapper.getc
    @iowrapper.close
    lambda { @iowrapper.ungetc(100) }.should raise_error(IOError)
  end
end
