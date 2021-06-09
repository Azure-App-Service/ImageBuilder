# IO::Like - in the Likeness of IO

A module which provides the functionality of an IO object to any including class
which provides a couple of simple methods.

## LINKS

* Homepage :: http://github.com/javanthropus/io-like
* Documentation :: http://rdoc.info/gems/io-like/frames
* Source :: http://github.com/javanthropus/io-like

## DESCRIPTION

The IO::Like module provides all of the methods of typical IO implementations
such as File; most importantly the read, write, and seek series of methods.  A
class which includes IO::Like needs to provide only a few methods in order to
enable the higher level methods.  Buffering is automatically provided by default
for the methods which normally provide it in IO.

## FEATURES

* All standard Ruby 1.8.6 IO operations.
* Buffered operations.
* Configurable buffer size.

## KNOWN BUGS/LIMITATIONS

* Only up to version 1.8.6 of Ruby's IO interface is implemented.
* Ruby's finalization capabilities fall a bit short in a few respects, and as a
  result, it is impossible to cause the close, close_read, or close_write
  methods to be called automatically when an including class is garbage
  collected.  Define a class open method in the manner of File.open which
  guarantees that an appropriate close method will be called after executing a
  block.  Other than that, be diligent about calling the close methods.

## SYNOPSIS

More examples can be found in the `examples` directory of the source
distribution.

A simple ROT13 codec:

```ruby
require 'io/like'

class ROT13Filter
  include IO::Like

  def self.open(delegate_io)
    filter = new(delegate_io)
    return filter unless block_given?

    begin
      yield(filter)
    ensure
      filter.close unless filter.closed?
    end
  end

  def initialize(delegate_io)
    @delegate_io = delegate_io
  end

  private

  def encode_rot13(string)
    result = string.dup
    0.upto(result.length) do |i|
      case result[i]
      when 65..90
        result[i] = (result[i] - 52) % 26 + 65
      when 97..122
        result[i] = (result[i] - 84) % 26 + 97
      end
    end
    result
  end

  def unbuffered_read(length)
    encode_rot13(@delegate_io.sysread(length))
  end

  def unbuffered_seek(offset, whence = IO::SEEK_SET)
    @delegate_io.sysseek(offset, whence)
  end

  def unbuffered_write(string)
    @delegate_io.syswrite(encode_rot13(string))
  end
end

File.open('normal_file.txt', 'w') do |f|
  f.puts('This is a test')
end

File.open('rot13_file.txt', 'w') do |f|
  ROT13Filter.open(f) do |rot13|
    rot13.puts('This is a test')
  end
end

File.open('normal_file.txt') do |f|
  ROT13Filter.open(f) do |rot13|
    puts(rot13.read)                      # -> Guvf vf n grfg
  end
end

File.open('rot13_file.txt') do |f|
  ROT13Filter.open(f) do |rot13|
    puts(rot13.read)                      # -> This is a test
  end
end

File.open('normal_file.txt') do |f|
  ROT13Filter.open(f) do |rot13|
    rot13.pos = 5
    puts(rot13.read)                      # -> vf n grfg
  end
end

File.open('rot13_file.txt') do |f|
  ROT13Filter.open(f) do |rot13|
    rot13.pos = 5
    puts(rot13.read)                      # -> is a test
  end
end

File.open('normal_file.txt') do |f|
  ROT13Filter.open(f) do |rot13|
    ROT13Filter.open(rot13) do |rot26|    # ;-)
      puts(rot26.read)                    # -> This is a test
    end
  end
end
```

## REQUIREMENTS

* None

## INSTALL

Download the GEM file and install it with:

    $ gem install io-like-VERSION.gem

or directly with:

    $ gem install io-like

Removal is the same in either case:

    $ gem uninstall io-like

## DEVELOPERS

After checking out the source, run:

    $ bundle install
    $ bundle exec rake test yard

This will install all dependencies, run the tests/specs, and generate the
documentation.

## AUTHORS and CONTRIBUTORS

Thanks to all contributors.  Without your help this project would not exist.

* Jeremy Bopp :: jeremy@bopp.net
* Jarred Holman :: jarred.holman@gmail.com
* Grant Gardner :: grant@lastweekend.com.au
* Jordan Pickwell :: jpickwell@users.noreply.github.com

## CONTRIBUTING

Contributions for bug fixes, documentation, extensions, tests, etc. are
encouraged.

1. Clone the repository.
2. Fix a bug or add a feature.
3. Add tests for the fix or feature.
4. Make a pull request.

### CODING STYLE

The following points are not necessarily set in stone but should rather be used
as a good guideline.  Consistency is the goal of coding style, and changes will
be more easily accepted if they are consistent with the rest of the code.

* **File Encoding**
  * UTF-8
* **Indentation**
  * Two spaces; no tabs
* **Line length**
  * Limit lines to a maximum of 80 characters
* **Comments**
  * Document classes, attributes, methods, and code
* **Method Calls with Arguments**
  * Use `a_method(arg, arg, etc)`; **not** `a_method( arg, arg, etc )`,
    `a_method arg, arg, etc`, or any other variation
* **Method Calls without Arguments**
  * Use `a_method`; avoid parenthesis
* **String Literals**
  * Use single quotes by default
  * Use double quotes when interpolation is necessary
  * Use `%{...}` and similar when embedding the quoting character is cumbersome
* **Blocks**
  * `do ... end` for multi-line blocks and `{ ... }` for single-line blocks
* **Boolean Operators**
  * Use `&&` and `||` for boolean tests; avoid `and` and `or`
* **In General**
  * Try to follow the flow and style of the rest of the code

## LICENSE

```
(The MIT License)

Copyright (c) 2020 Jeremy Bopp

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

## RUBYSPEC LICENSE

Files under the `rubyspec` directory are copied whole or in part from the
Rubyspec project.

```
Copyright (c) 2008 Engine Yard, Inc. All rights reserved.

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
```
