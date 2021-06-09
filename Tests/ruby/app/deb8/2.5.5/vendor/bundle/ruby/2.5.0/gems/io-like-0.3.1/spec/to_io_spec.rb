require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'

describe "IO::Like#to_io" do
  it "returns self for open stream" do
    IOSpecs.readable_iowrapper do |iowrapper|
      iowrapper.to_io.should == iowrapper
    end

    IOSpecs.writable_iowrapper do |iowrapper|
      iowrapper.to_io.should == iowrapper
    end
  end

  it "returns self for closed stream" do
    io = IOSpecs.closed_file
    io.to_io.should == io
  end
end
