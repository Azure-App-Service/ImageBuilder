require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'

describe "IO::Like#print" do
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
    @iowrapper.print('hello').should == nil
  end

  # MRI LIMITATION:
  # $_ will not cross into the implementation of print since its value is
  # limited to the local scope in managed code.
  #
  #it "writes $_ by default" do
  #  $_ = 'hello'
  #  @iowrapper.print()
  #  @iowrapper.close
  #  @file.close
  #  File.read(@filename).should == "hello\n"
  #end

  it "coerces arguments to strings using to_s" do
    data = 'abcdefgh9876'
    (obj = mock('test')).should_receive(:to_s).and_return(data)
    @iowrapper.print(obj)
    File.read(@filename).should == data
  end

  it "writes nil arguments as \"nil\"" do
    @iowrapper.print(nil)
    File.read(@filename).should == "nil"
  end

  it "appends $\\ to the output" do
    $\ = '->'
    data = 'abcdefgh9876'
    @iowrapper.print(data)
    File.read(@filename).should == "#{data}#{$\}"
  end

  it "does not append $\\ to the output when it is nil" do
    $\ = nil
    data = 'abcdefgh9876'
    @iowrapper.print(data)
    File.read(@filename).should == data
  end

  it "writes $, between arguments" do
    $, = '->'
    data1 = 'abcdefgh9876'
    data2 = '12345678zyxw'
    @iowrapper.print(data1, data2)
    File.read(@filename).should == "#{data1}#{$,}#{data2}"
  end

  it "does not write $, between arguments when it is nil" do
    $, = nil
    data1 = 'abcdefgh9876'
    data2 = '12345678zyxw'
    @iowrapper.print(data1, data2)
    File.read(@filename).should == "#{data1}#{data2}"
  end

  it "does not check if the file is writable if writing zero bytes" do
    lambda { IOSpecs.readable_iowrapper.print("") }.should_not raise_error
  end

  it "checks if the file is writable if writing more than zero bytes" do
    lambda do
      IOSpecs.readable_iowrapper.print("hello")
    end.should raise_error(IOError)
  end

  it "does not raise IOError on closed stream if writing zero bytes" do
    lambda { IOSpecs.closed_file.print("") }.should_not raise_error
  end

  it "raises IOError on closed stream if writing more than zero bytes" do
    lambda { IOSpecs.closed_file.print("hello") }.should raise_error(IOError)
  end
end
