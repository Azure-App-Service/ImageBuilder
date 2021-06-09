require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'

describe "IO::Like#read" do
  before :each do
    @filename = tmp('IO_Like__read_test')
    @contents = "1234567890"
    File.open(@filename, "w") { |io| io.write(@contents) }

    @file = File.open(@filename, "r+")
    @iowrapper = IOWrapper.open(@file)
  end

  after :each do
    @iowrapper.close unless @iowrapper.closed?
    @file.close unless @file.closed?
    File.delete(@filename) if File.exists?(@filename)
  end

  it "can be read from consecutively" do
    @iowrapper.read(1).should == '1'
    @iowrapper.read(2).should == '23'
    @iowrapper.read(3).should == '456'
    @iowrapper.read(4).should == '7890'
  end

  it "can read lots of data" do
    data = "\xaa" * (8096 * 2 + 1024) # HACK IO::BufferSize
    File.open(@filename, 'w') { |io| io.write(data) }
    actual = nil
    File.open(@filename, 'r') { |io| actual = io.read }

    actual.length.should == data.length
    actual.split('').all? { |c| c == "\xaa" }.should == true
  end

  it "can read lots of data with length" do
    read_length = 8096 * 2 + 1024 # HACK IO::BufferSize
    data = "\xaa" * (read_length + 8096) # HACK same
    File.open(@filename, 'w') { |io| io.write(data) }
    actual = nil
    File.open(@filename, 'r') { |io| actual = io.read(read_length) }

    actual.length.should == read_length
    actual.split('').all? { |c| c == "\xaa" }.should == true
  end

  it "consumes zero bytes when reading zero bytes" do
    pre_pos = @iowrapper.pos

    @iowrapper.read(0).should == ''
    @iowrapper.getc.chr.should == '1'
  end

  it "is at end-of-file when everything has been read" do
    @iowrapper.read
    @iowrapper.eof?.should == true
  end

  it "reads the contents of a file" do
    @iowrapper.read.should == @contents
  end

  it "places the specified number of bytes in the buffer" do
    buf = ""
    @iowrapper.read(5, buf)

    buf.should == "12345"
  end

  it "expands the buffer when too small" do
    buf = "ABCDE"
    @iowrapper.read(nil, buf)

    buf.should == @contents
  end

  it "overwrites the buffer" do
    buf = "ABCDEFGHIJ"
    @iowrapper.read(nil, buf)

    buf.should == @contents
  end

  it "truncates the buffer when too big" do
    buf = "ABCDEFGHIJKLMNO"
    @iowrapper.read(nil, buf)
    buf.should == @contents

    @iowrapper.rewind
    buf = "ABCDEFGHIJKLMNO"
    @iowrapper.read(5, buf)
    buf.should == @contents[0..4]
  end

  it "returns the given buffer" do
    buf = ""

    @iowrapper.read(nil, buf).object_id.should == buf.object_id
  end

  it "coerces the second argument to string and uses it as a buffer" do
    buf = "ABCDE"
    obj = mock("buff")
    obj.should_receive(:to_str).any_number_of_times.and_return(buf)

    @iowrapper.read(15, obj).object_id.should_not == obj.object_id
    buf.should == @contents
  end

  it "returns an empty string at end-of-file" do
    @iowrapper.read
    @iowrapper.read.should == ''
  end

  it "reads the contents of a file when more bytes are specified" do
    @iowrapper.read(@contents.length + 1).should == @contents
  end

  it "reads all data available before a SystemCallError is raised" do
    # Overrride @file.sysread to raise SystemCallError every other time it's
    # called.
    class << @file
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

    lambda { @iowrapper.read }.should raise_error(SystemCallError)
    @iowrapper.read.should == @contents
  end

  it "returns an empty string when the current pos is bigger than the content size" do
    @iowrapper.pos = 1000
    @iowrapper.read.should == ''
  end

  it "returns nil at end-of-file with a length" do
    @iowrapper.read
    @iowrapper.read(1).should == nil
  end

  it "with length argument returns nil when the current pos is bigger than the content size" do
    @iowrapper.pos = 1000
    @iowrapper.read(1).should == nil
  end

  it "raises IOError on write-only stream" do
    lambda { IOSpecs.writable_iowrapper.read }.should raise_error(IOError)
  end

  it "raises IOError on closed stream" do
    lambda { IOSpecs.closed_file.read }.should raise_error(IOError)
  end
end
