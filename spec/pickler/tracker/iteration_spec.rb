require File.expand_path(File.dirname(__FILE__) + '/../../../spec/spec_helper')

describe Pickler::Tracker::Iteration do

  before do
    @iteration = Pickler::Tracker::Iteration.new(nil, :start => "Jan 01, 2008", :finish => "Jan 08, 2008")
  end

  it "should have a start Date" do
    expect(@iteration.start).to eq Date.new(2008,1,1)
  end

  it "should have a finish Date" do
    expect(@iteration.finish).to eq Date.new(2008,1,8)
  end

  it "should have a range" do
    expect(@iteration.range).to be_kind_of(Range)
  end

  it "should not consider the start date part of the range" do
   expect(@iteration).to include(@iteration.start)
  end

  it "should not consider the finish date part of the range" do
   expect(@iteration).to_not include(@iteration.finish)
  end

end
