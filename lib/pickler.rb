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
    when 'finish'
      pickler.finish(argv.first)
    when 'help', '--help', '-h', '', nil
      puts 'pickler commands: show <id>, search <query>, push, pull, finish <id>'
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

  def remote_features
    project.stories(scenario_word, :includedone => true).select do |s|
      s.to_s =~ /^\s*#{Regexp.escape(scenario_word)}:/ && parser.parse(s.to_s)
    end
  end

  def local_features
    Dir[features_path('**','*.feature')].map {|f| LocalFeature.new(self,f)}
  end

  def feature(string)
    if string =~ /^(\d+)$/ || string =~ %r{^http://www\.pivotaltracker\.com/\S*/(\d+)}
      local_features.detect {|f| f && f.id.to_s == string}
    elsif !string
      raise Error, "No feature given"
    else
      paths = [features_path("#{string}.feature"),features_path(string),string]
      path = paths.detect {|p| File.exist?(p)}
      LocalFeature.new(self,path) if path
    end or raise Error, "Unrecogizable feature #{string}"
  end

  def story(string)
    if string =~ /^(\d+)$/ || string =~ %r{^http://www\.pivotaltracker\.com/\S*/(\d+)}
      project.story($1)
    else
      feature(string).story
    end
  end

  def pull(*args)
    l = local_features
    args.map! {|arg| story(arg)}
    args.replace(remote_features) if args.empty?
    args.each do |remote|
      body = "# http://www.pivotaltracker.com/story/show/#{remote.id}\n" <<
      normalize_feature(remote.to_s)
      if local = l.detect {|f| f.id == remote.id}
        filename = local.filename
      else
        next if remote.current_state == 'unstarted'
        filename = features_path("#{remote.id}.feature")
      end
      File.open(filename,'w') {|f| f.puts body}
    end
    nil
  end

  def push(*args)
    args.map! {|a| feature(a)}
    args.replace(local_features) if args.empty?
    args.select do |local|
      next unless local.id
      remote = local.story
      next if remote.to_s == local.to_s
      remote.to_s = local.to_s
      remote.save
    end
  end

  def finish(*args)
    push(*args).each do |local|
      remote = local.story
      remote.transition!("finished") unless remote.complete?
    end
  end

  protected

  def normalize_feature(body)
    return body unless ast = parser.parse(body)
    feature = ast.compile
    new = ''
    (feature.header.chomp << "\n").each_line do |l|
      new << '  ' unless new.empty?
      new << l.strip << "\n"
    end
    feature.scenarios.each do |scenario|
      new << "\n  Scenario: #{scenario.name}\n"
      scenario.steps.each do |step|
        new << "    #{step.keyword} #{step.name}\n"
      end
    end
    new
  end

  class LocalFeature
    attr_reader :pickler, :filename

    def initialize(pickler, filename)
      @pickler = pickler
      @filename = filename
    end

    def to_s
      File.read(@filename)
    end

    def id
      unless defined?(@id)
        @id = if id = to_s[%r{#\s*http://www\.pivotaltracker\.com/\S*/(\d+)},1]
                id.to_i
              end
      end
      @id
    end

    def story
      @story ||= @pickler.project.story(id) if id
    end

  end

end

require 'pickler/tracker'
