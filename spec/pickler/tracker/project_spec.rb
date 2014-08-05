require File.expand_path(File.dirname(__FILE__) + '/../../../spec/spec_helper')

describe Pickler::Tracker::Project do

  before do
    @tracker = Pickler::Tracker.new('')
    @project = @tracker.project(1)
  end

  it "should have an id Integer" do
    expect(@project.id).to be_kind_of(Integer)
  end

  it "should have a name String" do
    expect(@project.name).to be_kind_of(String)
  end

  it "should have an iteration length Integer" do
    expect(@project.iteration_length).to be_kind_of(Integer)
  end

  it "should have a week start day String" do
    expect(@project.week_start_day).to be_kind_of(String)
  end

  it "should have a point scale String" do
    expect(@project.point_scale).to be_kind_of(String)
  end

  it "should have a collection of stories" do
    expect(@project.stories.first).to be_kind_of(Pickler::Tracker::Story)
  end

  it "should retrieve a story by id" do
    expect(@project.story(1)).to be_kind_of(Pickler::Tracker::Story)
  end

  it "should have a story factory" do
    story = @project.new_story
    expect(story).to be_kind_of(Pickler::Tracker::Story)
    expect(story.id).to be_nil
  end

  it "should provide lazy load" do
    @project = Pickler::Tracker::Project.new(@tracker, 1) { {:point_scale => '0'} }
    expect(@project.id).to eq 1
    expect(@project.point_scale).to eq '0'
  end

end
