require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'
require File.dirname(__FILE__) + '/shared/eof'

describe "IO::Like#eof" do
  it_behaves_like :io_like__eof, :eof
end

describe "IO::Like#eof?" do
  it_behaves_like :io_like__eof, :eof?
end
