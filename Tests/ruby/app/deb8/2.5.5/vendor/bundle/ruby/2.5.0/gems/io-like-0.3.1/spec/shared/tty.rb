require File.dirname(__FILE__) + '/../fixtures/classes'

describe :io_like__tty, :shared => true do
  it "returns false if this stream is open" do
    IOSpecs.readable_iowrapper { |io| io.send(@method) }.should == false
    IOSpecs.writable_iowrapper { |io| io.send(@method) }.should == false
  end

  it "raises IOError on closed stream" do
    lambda { IOSpecs.closed_file.send(@method) }.should raise_error(IOError)
  end
end
