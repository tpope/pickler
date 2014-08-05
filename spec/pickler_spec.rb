require File.expand_path(File.dirname(__FILE__) + '/../spec/spec_helper')

describe Pickler do
  before do
    @pickler = Pickler.new(File.dirname(__FILE__))
  end

  it "should detect the project" do
    expect(@pickler.project.name).to eq "Sample Project"
  end
end
