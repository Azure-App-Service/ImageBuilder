require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'
require File.dirname(__FILE__) + '/shared/pos'

describe "IO::Like#tell" do
  it_behaves_like(:io_like__pos, :tell)
end
