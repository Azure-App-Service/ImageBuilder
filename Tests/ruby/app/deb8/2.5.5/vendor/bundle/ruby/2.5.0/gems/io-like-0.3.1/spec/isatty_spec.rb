require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/shared/tty'

describe "IO::Like#isatty" do
  it_behaves_like :io_like__tty, :isatty
end
