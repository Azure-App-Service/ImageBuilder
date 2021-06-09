require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'
require File.dirname(__FILE__) + '/shared/pos'

describe "IO::Like#pos" do
  it_behaves_like(:io_like__pos, :pos)
end

describe "IO::Like#pos=" do
  before :each do
    @fname = 'test.txt'
    File.open(@fname, 'w') { |f| f.write("123") }
  end

  after :each do
    File.unlink(@fname)
  end

  it "sets the offset" do
    File.open(@fname) do |f|
      ReadableIOWrapper.open(f) do |iowrapper|
        val1 = iowrapper.read(1)
        iowrapper.pos = 0
        iowrapper.read(1).should == val1
      end
    end
  end

  it "can handle any numerical argument without breaking" do
    File.open(@fname) do |f|
      ReadableIOWrapper.open(f) do |iowrapper|
        iowrapper.pos = 1.2
        iowrapper.pos.should == 1

        iowrapper.pos = 2**32
        iowrapper.pos.should == 2**32

        iowrapper.pos = 1.23423423432e12
        iowrapper.pos.should == Integer(1.23423423432e12)

        iowrapper.pos = Float::EPSILON
        iowrapper.pos.should == 0

        lambda { iowrapper.pos = 2**128 }.should raise_error(RangeError)
      end
    end
  end

  it "raises IOError on closed stream" do
    lambda { IOSpecs.closed_file.pos = 0 }.should raise_error(IOError)
  end
end

