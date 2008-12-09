require 'yaml'

class Pickler

  class Error < RuntimeError
  end

  autoload :Runner,  'pickler/runner'
  autoload :Feature, 'pickler/feature'
  autoload :Tracker, 'pickler/tracker'

  def self.config
    @config ||= {'api_token' => ENV["TRACKER_API_TOKEN"]}.merge(
      if File.exist?(path = File.expand_path('~/.tracker.yml'))
        YAML.load_file(path)
      end || {}
    )
  end

  def self.run(argv)
    Runner.new(argv).run
  end

  attr_reader :directory

  def initialize(path = '.')
    @lang = 'en'
    @directory = File.expand_path(path)
    until File.directory?(File.join(@directory,'features'))
      if @directory == File.dirname(@directory)
        raise Error, 'Project not found.  Make sure you have a features/ directory.', caller
      end
      @directory = File.dirname(@directory)
    end
  end

  def features_path(*subdirs)
    File.join(@directory,'features',*subdirs)
  end

  def config_file
    features_path('tracker.yml')
  end

  def config
    @config ||= File.exist?(config_file) && YAML.load_file(config_file) || {}
    self.class.config.merge(@config)
  end

  def parser
    require 'cucumber'
    require "cucumber/treetop_parser/feature_#@lang"
    Cucumber.load_language(@lang)
    @parser ||= Cucumber::TreetopParser::FeatureParser.new
  end

  def project_id
    config["project_id"] || (self.class.config["projects"]||{})[File.basename(@directory)]
  end

  def project
    @project ||= Dir.chdir(@directory) do
      unless token = config['api_token']
        raise Error, 'echo api_token: ... > ~/.tracker.yml'
      end
      unless id = project_id
        raise Error, 'echo project_id: ... > features/tracker.yml'
      end
      Tracker.new(token).project(id)
    end
  end

  def scenario_word
    parser
    Cucumber.language['scenario']
  end

  def local_features
    Dir[features_path('**','*.feature')].map {|f|feature(f)}.select {|f|f.id}
  end

  def scenario_features
    project.stories(scenario_word, :includedone => true).reject do |s|
      %(unscheduled unstarted).include?(s.current_state)
    end.select do |s|
      s.to_s =~ /^\s*#{Regexp.escape(scenario_word)}:/ && parser.parse(s.to_s)
    end
  end

  def feature(string)
    string.kind_of?(Feature) ? string : Feature.new(self,string)
  end

  def story(string)
    feature(string).story
  end

  protected

end
