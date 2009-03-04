require File.join(File.dirname(File.dirname(File.dirname(__FILE__))),'spec_helper')

describe Pickler::Tracker::Story do

  before do
    @tracker = Pickler::Tracker.new('')
    @project = @tracker.project(1)
    @story   = @project.story(1)
  end

  it "should have an id Integer" do
    @story.id.should be_kind_of(Integer)
  end

  it "should have an estimate Integer" do
    @story.estimate.should be_kind_of(Integer)
  end

  it "should return nil for a negative estimate" do
    @project.new_story(:estimate => "-1").estimate.should be_nil
  end

  it "should have a name String" do
    @story.name.should be_kind_of(String)
  end

  it "should have a url String" do
    @story.url.should be_kind_of(String)
  end

  it "should have a created_at Date" do
    @story.created_at.should respond_to(:day)
  end

  it "should have a accepted_at Date" do
    @story.accepted_at.should respond_to(:day)
  end

  it "should have a labels Array" do
    @project.new_story(:labels =>     nil).should have(0).labels
    @project.new_story(:labels =>     ' ').should have(0).labels
    @project.new_story(:labels =>   'foo').should have(1).labels
    @project.new_story(:labels => %w(x y)).should have(2).labels
    @project.new_story(:labels =>  'x, y').should have(2).labels
  end

  it "should have an iteration" do
    @story.iteration.should be_kind_of(Pickler::Tracker::Iteration)
  end

end
