require File.expand_path(File.dirname(__FILE__) + '/../../../spec/spec_helper')

describe Pickler::Tracker::Story do

  before do
    @tracker = Pickler::Tracker.new('')
    @project = @tracker.project(1)
    @story   = @project.story(1)
  end

  it "should have an id Integer" do
    expect(@story.id).to be_kind_of(Integer)
  end

  it "should have an estimate Integer" do
    expect(@story.estimate).to be_kind_of(Integer)
  end

  it "should return nil for a negative estimate" do
    expect(@project.new_story(:estimate => "-1").estimate).to be_nil
  end

  it "should persist -1 for a nil estimate assignment" do
    expect(@project.new_story(:estimate => nil).attributes['estimate']).to eq -1
  end

  it "should have a name String" do
    expect(@story.name).to be_kind_of(String)
  end

  it "should have a url String" do
    expect(@story.url).to be_kind_of(String)
  end

  it "should have a created_at Date" do
    expect(@story.created_at).to respond_to(:day)
  end

  it "should have a accepted_at Date" do
    expect(@story.accepted_at).to respond_to(:day)
  end

  it "should have a labels Array" do
    expect(@project.new_story(:labels =>     nil).labels.count).to eq 0
    expect(@project.new_story(:labels =>     ' ').labels.count).to eq 0
    expect(@project.new_story(:labels =>   'foo').labels.count).to eq 1
    expect(@project.new_story(:labels => %w(x y)).labels.count).to eq 2
    expect(@project.new_story(:labels =>  'x, y').labels.count).to eq 2
  end

  it "should have an iteration" do
    expect(@story.iteration).to be_kind_of(Pickler::Tracker::Iteration)
  end

  describe "#suggested_basename" do

    it "should return the user override if it's not blank or \"-\"" do
      story = @project.new_story(:name => "Name")
      expect(story.suggested_basename('foo_bar')).to eq 'foo_bar'
      expect(story.suggested_basename('')).to_not eq ''
      expect(story.suggested_basename('-')).to_not eq '-'
    end

    it "returns the id if no name is present" do
      expect(@project.new_story(:id => 123).suggested_basename).to eq '123'
    end

    it "sluggifies the name" do
      expect(@project.new_story(:name => "Foo: bar-baz").suggested_basename).to eq "foo_bar-baz"
    end

  end

end
