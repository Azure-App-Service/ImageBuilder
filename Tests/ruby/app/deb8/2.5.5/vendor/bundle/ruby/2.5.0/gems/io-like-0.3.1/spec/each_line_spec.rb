require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/fixtures/classes'
require File.dirname(__FILE__) + '/shared/each'

describe "IO::Like#each_line" do
  it_behaves_like :io_like__each, :each_line
end

describe "IO::Like#each_line when passed a separator" do
  it_behaves_like :io_like__each_separator, :each_line
end
