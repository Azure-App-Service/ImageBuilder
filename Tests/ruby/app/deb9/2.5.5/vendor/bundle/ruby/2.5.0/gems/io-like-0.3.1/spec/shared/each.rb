require File.dirname(__FILE__) + '/../fixtures/classes'

describe :io_like__each, :shared => true do
  before(:each) do
    @old_rs = $/
    @io = File.open(IOSpecs.gets_fixtures)
    @iowrapper = ReadableIOWrapper.open(@io)
  end

  after(:each) do
    @iowrapper.close
    @io.close
    $/ = @old_rs
  end

  it "returns self" do
    @iowrapper.send(@method) { |l| l }.should == @iowrapper
  end

  it "yields each line to the passed block" do
    seen = []
    @iowrapper.send(@method) { |s| seen << s }
    seen.should == [
      "Voici la ligne une.\n", "Qui \303\250 la linea due.\n", "\n", "\n",
      "Aqu\303\255 est\303\241 la l\303\255nea tres.\n",
      "Ist hier Linie vier.\n", "\n", "Est\303\241 aqui a linha cinco.\n",
      "Here is line six.\n"
    ]
  end

  it "yields each line starting from the current position" do
    seen = []
    @iowrapper.pos = 40
    @iowrapper.send(@method) { |s| seen << s }
    seen.should == [
      "\n", "\n", "\n", "Aqu\303\255 est\303\241 la l\303\255nea tres.\n",
      "Ist hier Linie vier.\n", "\n", "Est\303\241 aqui a linha cinco.\n",
      "Here is line six.\n"
    ]
  end

  it "does not change $_" do
    $_ = "test"
    @iowrapper.send(@method) { |s| s }
    $_.should == "test"
  end

  it "uses $/ as the default line separator" do
    seen = []
    $/ = " "
    @iowrapper.send(@method) { |s| seen << s }
    seen.should == [
      "Voici ", "la ", "ligne ", "une.\nQui ", "\303\250 ", "la ", "linea ",
      "due.\n\n\nAqu\303\255 ", "est\303\241 ", "la ", "l\303\255nea ",
      "tres.\nIst ", "hier ", "Linie ", "vier.\n\nEst\303\241 ", "aqui ",
      "a ", "linha ", "cinco.\nHere ", "is ", "line ", "six.\n"
    ]
  end

  it "raises IOError on write-only stream" do
    # method must have a block in order to raise the IOError.
    # MRI 1.8.7 returns enumerator if block is not provided.
    # See [ruby-core:16557].
    lambda do
      IOSpecs.writable_iowrapper do |iowrapper|
        iowrapper.send(@method) {}
      end
    end.should raise_error(IOError)
  end

  it "raises IOError on closed stream" do
    # method must have a block in order to raise the IOError.
    # MRI 1.8.7 returns enumerator if block is not provided.
    # See [ruby-core:16557].
    lambda { IOSpecs.closed_file.send(@method) {} }.should raise_error(IOError)
  end

  ruby_version_is "" ... "1.8.7" do
    it "yields a LocalJumpError when passed no block" do
      lambda { @iowrapper.send(@method) }.should raise_error(LocalJumpError)
    end
  end

  ruby_version_is "1.8.7" do
    it "returns an Enumerator when passed no block" do
      enum = @iowrapper.send(@method, " ")
      enum.instance_of?(Enumerable::Enumerator).should be_true

      enum.to_a.should == [
        "Voici la ligne une.\n", "Qui \303\250 la linea due.\n", "\n", "\n",
        "Aqu\303\255 est\303\241 la l\303\255nea tres.\n",
        "Ist hier Linie vier.\n", "\n", "Est\303\241 aqui a linha cinco.\n",
        "Here is line six.\n"
      ]
    end
  end
end

describe :io_like__each_separator, :shared => true do
  before(:each) do
    @io = File.open(IOSpecs.gets_fixtures)
    @iowrapper = ReadableIOWrapper.open(@io)
  end

  after(:each) do
    @iowrapper.close
    @io.close
  end

  it "returns self" do
    @iowrapper.send(@method, " ") { |l| l }.should equal(@iowrapper)
  end

  it "uses the passed argument as the line separator" do
    seen = []
    @iowrapper.send(@method, " ") { |s| seen << s }
    seen.should == [
      "Voici ", "la ", "ligne ", "une.\nQui ", "\303\250 ", "la ", "linea ",
      "due.\n\n\nAqu\303\255 ", "est\303\241 ", "la ", "l\303\255nea ",
      "tres.\nIst ", "hier ", "Linie ", "vier.\n\nEst\303\241 ", "aqui ", "a ",
      "linha ", "cinco.\nHere ", "is ", "line ", "six.\n"
    ]
  end

  it "does not change $_" do
    $_ = "test"
    @iowrapper.send(@method, " ") { |s| s }
    $_.should == "test"
  end

  it "tries to convert the passed separator to a String using #to_str" do
    obj = mock("to_str")
    obj.stub!(:to_str).and_return(" ")

    seen = []
    @iowrapper.send(@method, obj) { |l| seen << l }
    seen.should == [
      "Voici ", "la ", "ligne ", "une.\nQui ", "\303\250 ", "la ", "linea ",
      "due.\n\n\nAqu\303\255 ", "est\303\241 ", "la ", "l\303\255nea ",
      "tres.\nIst ", "hier ", "Linie ", "vier.\n\nEst\303\241 ", "aqui ", "a ",
      "linha ", "cinco.\nHere ", "is ", "line ", "six.\n"
    ]
  end

  it "yields self's content starting from the current position when the passed separator is nil" do
    seen = []
    @iowrapper.pos = 100
    @iowrapper.send(@method, nil) { |s| seen << s }
    seen.should == ["qui a linha cinco.\nHere is line six.\n"]
  end

  it "yields each paragraph when passed an empty String as separator" do
    seen = []
    para_file = File.dirname(__FILE__) + '/../fixtures/paragraphs.txt'
    File.open(para_file) do |io|
      ReadableIOWrapper.open(io) do |iowrapper|
        iowrapper.send(@method, "") { |s| seen << s }
      end
    end
    seen.should == ["This is\n\n", "an example\n\n", "of paragraphs."]
  end

  it "raises IOError on write-only stream" do
    # method must have a block in order to raise the IOError.
    # MRI 1.8.7 returns enumerator if block is not provided.
    # See [ruby-core:16557].
    lambda do
      IOSpecs.writable_iowrapper do |iowrapper|
        iowrapper.send(@method, " ") {}
      end
    end.should raise_error(IOError)
  end

  it "raises IOError on closed stream" do
    # method must have a block in order to raise the IOError.
    # MRI 1.8.7 returns enumerator if block is not provided.
    # See [ruby-core:16557].
    lambda do
      IOSpecs.closed_file.send(@method, " ") {}
    end.should raise_error(IOError)
  end

  ruby_version_is "" ... "1.8.7" do
    it "yields a LocalJumpError when passed no block" do
      lambda do
        @iowrapper.send(@method, " ")
      end.should raise_error(LocalJumpError)
    end
  end

  ruby_version_is "1.8.7" do
    it "returns an Enumerator when passed no block" do
      enum = @iowrapper.send(@method, " ")
      enum.instance_of?(Enumerable::Enumerator).should be_true

      enum.to_a.should == [
        "Voici ", "la ", "ligne ", "une.\nQui ", "\303\250 ", "la ", "linea ",
        "due.\n\n\nAqu\303\255 ", "est\303\241 ", "la ", "l\303\255nea ",
        "tres.\nIst ", "hier ", "Linie ", "vier.\n\nEst\303\241 ", "aqui ",
        "a ", "linha ", "cinco.\nHere ", "is ", "line ", "six.\n"
      ]
    end
  end
end
