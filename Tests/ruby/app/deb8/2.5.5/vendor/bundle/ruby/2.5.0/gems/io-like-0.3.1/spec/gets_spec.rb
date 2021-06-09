require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'

describe "IO::Like#gets" do
  it "returns the next line of string that were separated by $/" do
    IOSpecs.readable_iowrapper do |f|
      IOSpecs.lines.each { |line| line.should == f.gets }
    end
  end

  it "returns tainted strings" do
    IOSpecs.readable_iowrapper do |f|
      while (line = f.gets(nil))
        line.tainted?.should == true
      end
    end

    IOSpecs.readable_iowrapper do |f|
      while (line = f.gets(""))
        line.tainted?.should == true
      end
    end

    IOSpecs.readable_iowrapper do |f|
      while (line = f.gets)
        line.tainted?.should == true
      end
    end

    IOSpecs.readable_iowrapper do |f|
      while (line = f.gets("la"))
        line.tainted?.should == true
      end
    end
  end

  it "updates lineno with each invocation" do
    count = 1
    IOSpecs.readable_iowrapper do |f|
      while (line = f.gets(nil))
        f.lineno.should == count
        count += 1
      end
    end

    count = 1
    IOSpecs.readable_iowrapper do |f|
      while (line = f.gets(""))
        f.lineno.should == count
        count += 1
      end
    end

    count = 1
    IOSpecs.readable_iowrapper do |f|
      while (line = f.gets)
        f.lineno.should == count
        count += 1
      end
    end

    count = 1
    IOSpecs.readable_iowrapper do |f|
      while (line = f.gets("la"))
        f.lineno.should == count
        count += 1
      end
    end
  end

  it "updates $. with each invocation" do
    count = 1
    IOSpecs.readable_iowrapper do |f|
      while (line = f.gets(nil))
        $..should == count
        count += 1
      end
    end

    count = 1
    IOSpecs.readable_iowrapper do |f|
      while (line = f.gets(""))
        $..should == count
        count += 1
      end
    end

    count = 1
    IOSpecs.readable_iowrapper do |f|
      while (line = f.gets)
        $..should == count
        count += 1
      end
    end

    count = 1
    IOSpecs.readable_iowrapper do |f|
      while (line = f.gets("la"))
        $..should == count
        count += 1
      end
    end
  end

  # MRI LIMITATION:
  # $_ will not cross out of the implementation of gets since its value is
  # limited to the local scope in managed code.
  #
  #it "assigns the returned line to $_" do
  #  IOSpecs.readable_iowrapper do |f|
  #    IOSpecs.lines.each do |line|
  #      f.gets
  #      $line.should == line
  #    end
  #  end
  #end

  it "returns nil if called at the end of the stream" do
    IOSpecs.readable_iowrapper do |f|
      IOSpecs.lines.length.times { f.gets }
      f.gets.should == nil
    end
  end

  it "returns the entire content if the separator is nil" do
    IOSpecs.readable_iowrapper do |f|
      f.gets(nil).should == IOSpecs.lines.join('')
    end
  end

  it "reads and returns all data available before a SystemCallError is raised when the separator is nil" do
    file = File.open(IOSpecs.gets_fixtures)
    # Overrride file.sysread to raise SystemCallError every other time it's
    # called.
    class << file
      alias :sysread_orig :sysread
      def sysread(length)
        if @error_raised then
          @error_raised = false
          sysread_orig(length)
        else
          @error_raised = true
          raise SystemCallError, 'Test Error'
        end
      end
    end

    ReadableIOWrapper.open(file) do |iowrapper|
      lambda { iowrapper.gets(nil) }.should raise_error(SystemCallError)
      iowrapper.gets(nil).should == IOSpecs.lines.join('')
    end
    file.close
  end

  # Two successive newlines in the input separate paragraphs.
  # When there are more than two successive newlines, only two are kept.
  it "returns the next paragraph if the separator's length is 0" do
    a = "Voici la ligne une.\nQui \303\250 la linea due.\n\n"
    b = "Aqu\303\255 est\303\241 la l\303\255nea tres.\nIst hier Linie vier.\n\n"
    c = "Est\303\241 aqui a linha cinco.\nHere is line six.\n"

    IOSpecs.readable_iowrapper do |f|
      f.gets("").should == a
      f.gets("").should == b
      f.gets("").should == c
    end
  end

  # This could probably be added to the previous test using pos, but right now
  # this doesn't pass and the previous test does.
  it "reads until the beginning of the next paragraph when the separator's length is 0" do
    # Leverage the fact that there are three newlines between the first and
    # second paragraph.
    IOSpecs.readable_iowrapper do |f|
      f.gets('')

      # This should return 'A', the first character of the next paragraph, not
      # $/.
      f.read(1).should == 'A'
    end
  end

  it "raises an IOError if the stream is not opened for reading" do
    path = tmp("gets_spec")
    lambda do
      File.open(path, 'w') do |f|
        WritableIOWrapper.open(f) { |iowrapper| iowrapper.gets }
      end
    end.should raise_error(IOError)
    File.unlink(path) if File.exist?(path)
  end

  it "raises IOError on closed stream" do
    lambda { IOSpecs.closed_file.gets }.should raise_error(IOError)
  end

  it "accepts a separator" do
    path = tmp("gets_specs")
    f = File.open(path, "w")
    f.print("A\n\n\nB\n")
    f.close
    f = File.open(path, "r")
    iowrapper = ReadableIOWrapper.open(f)
    iowrapper.gets("\n\n")
    b = iowrapper.gets("\n\n")
    iowrapper.gets("\n\n")
    iowrapper.close
    f.close
    b.should == "\nB\n"
    File.unlink(path)
  end
end
