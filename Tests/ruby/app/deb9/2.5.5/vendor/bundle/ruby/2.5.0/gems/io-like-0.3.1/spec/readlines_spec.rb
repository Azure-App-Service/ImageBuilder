require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'

describe "IO::Like#readlines when passed no arguments" do
  before(:each) do
    @io = File.open(File.dirname(__FILE__) + '/fixtures/readlines.txt')
    @iowrapper = IOWrapper.open(@io)
  end

  after(:each) do
    @iowrapper.close
    @io.close
  end

  it "returns an Array containing lines based on $/" do
    begin
      old_sep, $/ = $/, " "
      @iowrapper.readlines.should == [
        "Voici ", "la ", "ligne ", "une.\nQui ", "\303\250 ", "la ", "linea ",
        "due.\nAqu\303\255 ", "est\303\241 ", "la ", "l\303\255nea ",
        "tres.\nIst ", "hier ", "Linie ", "vier.\nEst\303\241 ", "aqui ", "a ",
        "linha ", "cinco.\nHere ", "is ", "line ", "six.\n"
      ]
    ensure
      $/ = old_sep
    end
  end

  it "updates self's position" do
    @iowrapper.readlines
    @iowrapper.pos.should eql(134)
  end

  it "updates self's lineno based on the number of lines read" do
    @iowrapper.readlines
    @iowrapper.lineno.should eql(6)
  end

  it "does not change $_" do
    $_ = "test"
    @iowrapper.readlines(">")
    $_.should == "test"
  end

  it "returns an empty Array when self is at the end" do
    @iowrapper.pos = 134
    @iowrapper.readlines.should == []
  end
end

describe "IO::Like#readlines when passed [separator]" do
  before(:each) do
    @io = File.open(File.dirname(__FILE__) + '/fixtures/readlines.txt')
    @iowrapper = IOWrapper.open(@io)
  end

  after(:each) do
    @iowrapper.close
    @io.close
  end

  it "returns an Array containing lines based on the passed separator" do
    @iowrapper.readlines('r').should == [
      "Voici la ligne une.\nQui \303\250 la linea due.\nAqu\303\255 est\303\241 la l\303\255nea tr",
      "es.\nIst hier",
      " Linie vier",
      ".\nEst\303\241 aqui a linha cinco.\nHer",
      "e is line six.\n"
    ]
  end

  it "returns an empty Array when self is at the end" do
    @iowrapper.pos = 134
    @iowrapper.readlines('r').should == []
  end

  it "updates self's lineno based on the number of lines read" do
    @iowrapper.readlines('r')
    @iowrapper.lineno.should eql(5)
  end

  it "updates self's position based on the number of characters read" do
    @iowrapper.readlines("r")
    @iowrapper.pos.should eql(134)
  end

  it "does not change $_" do
    $_ = "test"
    @iowrapper.readlines("r")
    $_.should == "test"
  end

  it "returns an Array containing all paragraphs when the passed separator is an empty String" do
    IOWrapper.open(File.open(File.dirname(__FILE__) + '/fixtures/paragraphs.txt')) do |io|
      io.readlines("").should == [
        "This is\n\n",
        "an example\n\n",
        "of paragraphs."
      ]
    end
  end

  it "returns the remaining content as one line starting at the current position when passed nil" do
    @iowrapper.pos = 5
    @iowrapper.readlines(nil).should == [
      " la ligne une.\nQui \303\250 la linea due.\n" +
      "Aqu\303\255 est\303\241 la l\303\255nea tres.\n" +
      "Ist hier Linie vier.\nEst\303\241 aqui a linha cinco.\n" +
      "Here is line six.\n"
    ]
  end

  it "tries to convert the passed separator to a String using #to_str" do
    obj = mock('to_str')
    obj.stub!(:to_str).and_return("r")
    @iowrapper.readlines(obj).should == [
      "Voici la ligne une.\nQui \303\250 la linea due.\nAqu\303\255 est\303\241 la l\303\255nea tr",
      "es.\nIst hier",
      " Linie vier",
      ".\nEst\303\241 aqui a linha cinco.\nHer",
      "e is line six.\n"]
  end
end

describe "IO::Like#readlines when in write-only mode" do
  it "raises an IOError" do
    path = tmp("write_only_specs")
    IOWrapper.open(File.open(path, 'a')) do |io|
      lambda { io.readlines }.should raise_error(IOError)
    end

    File.open(path) do |io|
      IOWrapper.open(io) do |iowrapper|
        io.close_read
        lambda { iowrapper.readlines }.should raise_error(IOError)
      end
    end
    File.unlink(path) if File.exists?(path)
  end
end
