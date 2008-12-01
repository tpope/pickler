require 'yaml'

class Pickler

  class Error < RuntimeError
  end

  def self.config
    @config ||= {'api_token' => ENV["TRACKER_API_TOKEN"]}.merge(
      if File.exist?(path = File.expand_path('~/.tracker.yml'))
        YAML.load_file(path)
      end || {}
    )
  end

  def self.run(argv)
    pickler = new(Dir.getwd)

    case first = argv.shift
    when 'show', /^\d+$/
      story = pickler.project.story(first == 'show' ? argv.shift : first)
      puts story
    when 'search'
      stories = pickler.project.stories(*argv).group_by {|s| s.current_state}
      first = true
      states = Tracker::Story::STATES
      states -= %w(unstarted accepted) if argv.empty?
      states.each do |state|
        next unless stories[state]
        puts unless first
        first = false
        puts state.upcase
        puts '-' * state.length
        stories[state].each do |story|
          puts "[#{story.id}] #{story.story_type.capitalize}: #{story.name}"
        end
      end
    when 'push'
      pickler.push(*argv)
    when 'pull'
      pickler.pull(*argv)
    when 'start'
      pickler.start(argv.first)
    when 'finish'
      pickler.finish(argv.first)
    when 'help', '--help', '-h', '', nil
      puts 'pickler commands: [show|start|finish] <id>, search <query>, push, pull'
    else
      $stderr.puts "pickler: unknown command #{first}"
      exit 1
    end
  rescue Pickler::Error
    $stderr.puts "#$!"
    exit 1
  rescue Interrupt
    $stderr.puts "Interrupted!"
    exit 130
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

  def features(*args)
    if args.any?
      args.map {|a| feature(a)}
    else
      Dir[features_path('**','*.feature')].map {|f|feature(f)}.select {|f|f.id}
    end
  end

  def feature(string)
    Feature.new(self,string)
  end

  def story(string)
    feature(string).story
  end

  def pull(*args)
    if args.empty?
      args = project.stories(scenario_word, :includedone => true).reject do |s|
        s.current_state == 'unstarted'
      end.select do |s|
        s.to_s =~ /^\s*#{Regexp.escape(scenario_word)}:/ && parser.parse(s.to_s)
      end
    end
    args.each do |arg|
      feature(arg).pull
    end
  end

  def start(*args)
    args.each do |arg|
      story = story(arg)
      story.transition!("started") if %w(unstarted rejected).include?(story.current_state)
    end
    pull(*args)
  end

  def push(*args)
    features(*args).each do |feature|
      feature.push
    end
  end

  def finish(*args)
    features(*args).each do |feature|
      feature.finish
    end
  end

  protected

end

require 'pickler/feature'
require 'pickler/tracker'
