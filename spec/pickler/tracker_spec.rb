require File.expand_path(File.dirname(__FILE__) + '/../../spec/spec_helper')

describe Pickler::Tracker do

  before do
    @tracker = Pickler::Tracker.new('')
  end

  it "should retrieve a project by id" do
    expect(@tracker.project(1)).to be_kind_of(Pickler::Tracker::Project)
  end

end
