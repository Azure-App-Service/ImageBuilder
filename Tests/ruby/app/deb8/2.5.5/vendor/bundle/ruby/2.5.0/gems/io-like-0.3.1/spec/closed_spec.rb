require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'

describe "IO::Like#closed?" do
  it "returns true on closed stream" do
    IOSpecs.closed_file.closed?.should == true
  end

  it "returns false on open stream" do
    File.open(File.dirname(__FILE__) + '/fixtures/gets.txt', 'r') do |io|
      ReadableIOWrapper.open(io) do |iowrapper|
        iowrapper.closed?.should == false
      end
    end
  end
end
