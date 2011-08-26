require File.expand_path(File.dirname(__FILE__) + '/../../../spec/spec_helper')

describe Pickler::Tracker::Project do

  before do
    @tracker = Pickler::Tracker.new('')
    @project = @tracker.project(1)
  end

  it "should have an id Integer" do
    @project.id.should be_kind_of(Integer)
  end

  it "should have a name String" do
    @project.name.should be_kind_of(String)
  end

  it "should have an iteration length Integer" do
    @project.iteration_length.should be_kind_of(Integer)
  end

  it "should have a week start day String" do
    @project.week_start_day.should be_kind_of(String)
  end

  it "should have a point scale String" do
    @project.point_scale.should be_kind_of(String)
  end

  it "should have a collection of stories" do
    @project.stories.first.should be_kind_of(Pickler::Tracker::Story)
  end

  it "should retrieve a story by id" do
    @project.story(1).should be_kind_of(Pickler::Tracker::Story)
  end

  it "should have a story factory" do
    story = @project.new_story
    story.should be_kind_of(Pickler::Tracker::Story)
    story.id.should be_nil
  end

  it "should provide lazy load" do
    @project = Pickler::Tracker::Project.new(@tracker, 1) { {:point_scale => '0'} }
    @project.id.should == 1
    @project.point_scale.should == '0'
  end

end
