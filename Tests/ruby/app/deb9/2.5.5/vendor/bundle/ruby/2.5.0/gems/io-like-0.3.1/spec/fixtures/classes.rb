require File.dirname(__FILE__) + '/../../lib/io/like'

class IOWrapper
  include IO::Like

  def self.open(io)
    iow = new(io)
    return iow unless block_given?

    begin
      yield(iow)
    ensure
      iow.close unless iow.closed?
    end
  end

  def initialize(io)
    @io = io
  end

  private

  def unbuffered_read(length)
    @io.sysread(length)
  end

  def unbuffered_seek(offset, whence = IO::SEEK_SET)
    @io.sysseek(offset, whence)
  end

  def unbuffered_write(string)
    @io.syswrite(string)
  end
end

class DuplexedIOWrapper < IOWrapper
  def duplexed?
    true
  end
end

class ReadableIOWrapper < IOWrapper
  def writable?
    false
  end
end

class WritableIOWrapper < IOWrapper
  def readable?
    false
  end
end

module IOSpecs
  def self.lines
    [
      "Voici la ligne une.\n",
      "Qui \303\250 la linea due.\n",
      "\n",
      "\n",
      "Aqu\303\255 est\303\241 la l\303\255nea tres.\n",
      "Ist hier Linie vier.\n",
      "\n",
      "Est\303\241 aqui a linha cinco.\n",
      "Here is line six.\n"
    ]
  end

  def self.gets_fixtures
    File.dirname(__FILE__) + '/gets.txt'
  end

  def self.gets_output
    File.dirname(__FILE__) + '/gets_output.txt'
  end

  def self.closed_file
    File.open(gets_fixtures, 'r') do |f|
      ReadableIOWrapper.open(f) { |iowrapper| iowrapper }
    end
  end

  def self.readable_iowrapper(&b)
    File.open(gets_fixtures, 'r') do |f|
      ReadableIOWrapper.open(f, &b)
    end
  end

  def self.writable_iowrapper(&b)
    File.open(gets_output, 'w') do |f|
      WritableIOWrapper.open(f, &b)
    end
  ensure
    File.delete(gets_output)
  end
end
