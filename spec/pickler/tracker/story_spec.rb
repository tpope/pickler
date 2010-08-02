require File.expand_path(File.dirname(__FILE__) + '/../../../spec/spec_helper')

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

  it "should persist -1 for a nil estimate assignment" do
    @project.new_story(:estimate => nil).instance_variable_get(:@attributes)['estimate'].should == -1
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

  describe "#suggested_basename" do

    it "should return the user override if it's not blank or \"-\"" do
      story = @project.new_story(:name => "Name")
      story.suggested_basename('foo_bar').should eql('foo_bar')
      story.suggested_basename('').should_not eql('')
      story.suggested_basename('-').should_not eql('-')
    end

    it "returns the id if no name is present" do
      @project.new_story(:id => 123).suggested_basename.should eql('123')
    end

    it "sluggifies the name" do
      @project.new_story(:name => "Foo: bar-baz").suggested_basename.should eql("foo_bar-baz")
    end

  end

end
