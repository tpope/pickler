require File.join(File.dirname(File.dirname(File.dirname(__FILE__))),'spec_helper')

describe Pickler::Tracker::Note do

  before do
    @note = Pickler::Tracker::Note.new(nil, :date => "Jan 2, 2008")
  end

  it "should have a date" do
    @note.date.should == Date.new(2008,1,2)
  end

end
