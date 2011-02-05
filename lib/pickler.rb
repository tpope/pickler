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

  def self.hash_to_xml(root, attributes)
    require 'cgi'
    xml = "<#{root}>"
    attributes.each do |k,v|
      if v.kind_of?(Hash)
        xml << hash_to_xml(k, v)
      else
        xml << "<#{k}>#{CGI.escapeHTML(v.to_s)}</#{k}>"
      end
    end
    xml << "</#{root}>"
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

  def real_name
    config["real_name"] || (require 'etc'; Etc.getpwuid.gecos.split(',').first)
  end

  def new_story(attributes = {}, &block)
    attributes = attributes.inject('requested_by' => real_name) do |h,(k,v)|
      h.update(k.to_s => v)
    end
    project.new_story(attributes, &block)
  end

  def stories(*args)
    project.stories(*args)
  end

  def name
    project.name
  end

  def iteration_length
    project.iteration_length
  end

  def point_scale
    project.point_scale
  end

  def week_start_day
    project.week_start_day
  end

  def deliver_all_finished_stories
    project.deliver_all_finished_stories
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
      ssl = config['ssl']
      Tracker.new(token, ssl).project(id)
    end
  end

  def scenario_word
    if @lang == 'en'
      'Scenario'
    else
      raise Error, 'Sorry, no internationalization support (yet)'
    end
  end

  def format
    (config['format'] || :tag).to_sym
  end

  def local_features
    Dir[features_path('**','*.feature')].map {|f|feature(f)}.select {|f|f.pushable?}
  end

  def scenario_features(excluded_states = %w(unscheduled unstarted))
    project.stories(scenario_word, :includedone => true).reject do |s|
      Array(excluded_states).map {|state| state.to_s}.include?(s.current_state)
    end.select do |s|
      s.to_s =~ /^\s*#{Regexp.escape(scenario_word)}:/
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
