require File.join(File.dirname(File.dirname(File.dirname(__FILE__))),'spec_helper')

describe Pickler::Tracker::Note do

  before do
    @text = ""
    @note = Pickler::Tracker::Note.new(nil, :date => "Jan 2, 2008", :text => @text)
  end

  it "should have a date" do
    @note.date.should == Date.new(2008,1,2)
  end

  describe "#lines" do
    it "should strip leading and trailing whitespace" do
      @text.replace(" x ")
      @note.lines.should == ["x"]
    end

    it "should favor the longest possible line" do
      @text.replace(("x"*35+" ")*3)
      @note.lines.should == ["x"*35+" "+"x"*35,"x"*35]
    end

    it "should not break a long word" do
      @text.replace("x"*81)
      @note.lines.should == ["x"*81]
    end

    it "should honor newlines" do
      @text.replace("a\nb\n\nc")
      @note.lines.should == ["a","b","","c"]
    end
  end

end
