require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'

# TODO: need to find a better way to test this. Too fragile to set expectations
# to each write call. Only care that all the characters are sent not the number
# or write calls. Also, these tests do not make sure the ordering of the write calls
# are correct.
describe "IO::Like#puts" do
  before :each do
    @old_record_separator = $\
    @old_field_separator = $,
    @filename = tmp('IO_Like__print_test')
    @file = File.open(@filename, 'w')
    @file.sync = true
    @iowrapper = WritableIOWrapper.open(@file)
    @iowrapper.sync = true
  end

  after :each do
    $\ = @old_record_separator
    $, = @old_field_separator
    @iowrapper.close unless @iowrapper.closed?
    @file.close unless @file.closed?
  end

  it "returns nil" do
    @iowrapper.puts('hello').should == nil
  end

  it "writes just a newline when given no args" do
    @iowrapper.puts()
    File.read(@filename).should == "\n"
  end

  it "writes just a newline when given just a newline" do
    @iowrapper.puts("\n")
    File.read(@filename).should == "\n"
  end

  it "writes nil with a newline when given nil as an arg" do
    @iowrapper.puts(nil)
    File.read(@filename).should == "nil\n"
  end

  it "coerces arguments to strings using to_s" do
    data = 'abcdefgh9876'
    (obj = mock('test')).should_receive(:to_s).and_return(data)
    @iowrapper.puts(obj)
    File.read(@filename).should == "#{data}\n"
  end

  it "writes each arg if given several" do
    data1 = 'abcdefgh9876'
    data2 = '12345678zyxw'
    @iowrapper.puts(data1, data2)
    File.read(@filename).should == "#{data1}\n#{data2}\n"
  end

  it "flattens a nested array before writing it" do
    data = ['abcdefgh9876', '12345678zyxw']
    @iowrapper.puts(data)
    File.read(@filename).should == "#{data[0]}\n#{data[1]}\n"
  end

  it "writes [...] for a recursive array arg" do
    data = []
    data << 1 << data << 2
    @iowrapper.puts(data)
    File.read(@filename).should == "#{data[0]}\n[...]\n#{data[2]}\n"
  end

  it "writes a newline after objects that do not end in newlines" do
    data = 'abcdefgh9876'
    @iowrapper.puts(data)
    File.read(@filename).should == "#{data}\n"
  end

  it "does not write a newline after objects that end in newlines" do
    data = "abcdefgh9876\n"
    @iowrapper.puts(data)
    File.read(@filename).should == data
  end

  it "ignores the $\ separator global" do
    $\ = ":"
    data1 = 'abcdefgh9876'
    data2 = '12345678zyxw'
    @iowrapper.puts(data1, data2)
    File.read(@filename).should == "#{data1}\n#{data2}\n"
  end

  it "raises IOError on read-only stream" do
    lambda { IOSpecs.readable_iowrapper.puts }.should raise_error(IOError)
  end

  it "raises IOError on closed stream" do
    lambda { IOSpecs.closed_file.puts }.should raise_error(IOError)
  end
end
