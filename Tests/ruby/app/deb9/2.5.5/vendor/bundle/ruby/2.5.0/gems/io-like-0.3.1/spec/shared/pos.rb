describe :io_like__pos, :shared => true do
  before :each do
    @fname = tmp('IO_Like__pos_test')
    File.open(@fname, 'w') { |f| f.write("123") }
  end

  after :each do
    File.unlink(@fname)
  end

  it "gets the offset" do
    IOSpecs.readable_iowrapper do |iowrapper|
      iowrapper.send(@method).should == 0
      iowrapper.read(1)
      iowrapper.send(@method).should == 1
      iowrapper.read(2)
      iowrapper.send(@method).should == 3
    end
  end

  it "raises IOError on closed stream" do
    lambda { IOSpecs.closed_file.send(@method) }.should raise_error(IOError)
  end

  # BOGUS EXPECTATION
  # This fails for File and IO.  It used to pass because the end of file was not
  # actually reached with just 2 bytes read from the file.
  #it "resets #eof?" do
  #  File.open(@fname) do |f|
  #    ReadableIOWrapper.open(f) do |iowrapper|
  #      iowrapper.read(1)
  #      iowrapper.read(1)
  #      iowrapper.eof?.should == true
  #      iowrapper.send(@method)
  #      iowrapper.eof?.should == false
  #    end
  #  end
  #end
end
