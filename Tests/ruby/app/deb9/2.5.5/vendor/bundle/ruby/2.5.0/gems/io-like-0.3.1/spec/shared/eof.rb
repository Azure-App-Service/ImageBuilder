require File.dirname(__FILE__) + '/../fixtures/classes'

describe :io_like__eof, :shared => true do
  before :each do
    @filename = File.dirname(__FILE__) + '/../fixtures/readlines.txt'
    @file = File.open(@filename, 'r')
    @iowrapper = ReadableIOWrapper.open(@file)
  end

  after :each do
    @iowrapper.close unless @iowrapper.closed?
    @file.close unless @file.closed?
  end

  it "returns false when not at end of file" do
    @iowrapper.send(@method).should == false
    @iowrapper.read(1)
    @iowrapper.send(@method).should == false
  end

  it "returns true after reading with read with no parameters" do
    @iowrapper.read
    @iowrapper.send(@method).should == true
  end

  it "returns true after reading with read" do
    @iowrapper.read(File.size(@filename))
    @iowrapper.send(@method).should == true
  end

  it "returns true after reading with sysread" do
    @iowrapper.sysread(File.size(@filename))
    @iowrapper.send(@method).should == true
  end

  it "returns true after reading with readlines" do
    @iowrapper.readlines
    @iowrapper.send(@method).should == true
  end

  it "returns true on just opened empty stream" do
    path = tmp('empty.txt')
    File.open(path, "w") { |empty| } # ensure it exists
    File.open(path) do |empty|
      ReadableIOWrapper.open(empty) do |iowrapper|
        iowrapper.send(@method).should == true
      end
    end
    File.delete(path)
  end

  it "returns false on just opened non-empty stream" do
    @iowrapper.send(@method).should == false
  end

  it "should not consume the data from the stream" do
    @iowrapper.send(@method).should == false
    @iowrapper.getc.should == 86
  end

  it "raises IOError on closed stream" do
    lambda { IOSpecs.closed_file.send(@method) }.should raise_error(IOError)
  end

  it "raises IOError on stream not opened for reading" do
    IOSpecs.writable_iowrapper do |iowrapper|
      lambda { iowrapper.send(@method) }.should raise_error(IOError)
    end
  end

  it "raises IOError on stream closed for reading by close_read" do
    @iowrapper.close_read
    lambda { @iowrapper.send(@method) }.should raise_error(IOError)
  end

  it "returns true on one-byte stream after single-byte read" do
    File.open(File.dirname(__FILE__) + '/../fixtures/one_byte.txt') do |one_byte|
      WritableIOWrapper.open(one_byte) do |iowrapper|
        one_byte.read(1)
        one_byte.send(@method).should == true
      end
    end
  end

  it "returns true on receiving side of Pipe when writing side is closed" do
    r, w = IO.pipe
    iowrapper_r = ReadableIOWrapper.open(r)
    iowrapper_w = WritableIOWrapper.open(w)
    iowrapper_w.close
    w.close

    iowrapper_r.send(@method).should == true

    iowrapper_r.close
    r.close
  end

  it "returns false on receiving side of Pipe when writing side wrote some data" do
    r, w = IO.pipe
    iowrapper_r = ReadableIOWrapper.open(r)
    iowrapper_w = WritableIOWrapper.open(w)
    iowrapper_w.sync = true

    iowrapper_w.puts "hello"
    iowrapper_r.send(@method).should == false
    iowrapper_w.close
    w.close

    iowrapper_r.send(@method).should == false
    iowrapper_r.read
    iowrapper_r.send(@method).should == true

    iowrapper_r.close
    r.close
  end
end
