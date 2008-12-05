require File.join(File.dirname(__FILE__),'spec_helper')

describe Pickler do
  before do
    @pickler = Pickler.new(File.dirname(__FILE__))
  end

  it "should detect the project" do
    @pickler.project.name.should == "Sample Project"
  end
end
