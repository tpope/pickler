require File.expand_path(File.dirname(__FILE__) + '/../../../spec/spec_helper')

describe Pickler::Tracker::Iteration do

  before do
    @iteration = Pickler::Tracker::Iteration.new(nil, :start => "Jan 01, 2008", :finish => "Jan 08, 2008")
  end

  it "should have a start Date" do
    @iteration.start.should == Date.new(2008,1,1)
  end

  it "should have a finish Date" do
    @iteration.finish.should == Date.new(2008,1,8)
  end

  it "should have a range" do
    @iteration.range.should be_kind_of(Range)
  end

  it "should not consider the start date part of the range" do
    @iteration.should include(@iteration.start)
  end

  it "should not consider the finish date part of the range" do
    @iteration.should_not include(@iteration.finish)
  end

end
