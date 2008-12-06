require 'optparse'

class Pickler
  class Runner

    class Base
      attr_reader :argv

      def initialize(argv)
        @argv = argv
        @tty = $stdout.tty?
        @opts = OptionParser.new
        @opts.version = "0.0"
        @opts.banner = "Usage: pickler #{self.class.command_name} #{self.class.banner_arguments}"
        @opts.base.long["help"] = OptionParser::Switch::NoArgument.new do
          help = @opts.help.chomp.chomp + "\n"
          help += "\n#{self.class.description}" if self.class.description
          puts help
          @exit = 0
        end
        @opts.separator("")
      end

      def self.options
        @options ||= []
      end

      def self.on(*args, &block)
        options << args
        define_method("option_#{args.object_id}", &block)
      end

      def self.banner_arguments(value = nil)
        if value
          @banner_arguments = value
        else
          @banner_arguments || (arity.zero? ? "" : "...")
        end
      end

      def self.description(value = nil)
        if value
          @description = value
        else
          @description
        end
      end

      def self.command_name
        name.split('::').last.gsub(/(.)([A-Z])/) {"#$1-#$2"}.downcase
      end

      def self.method_name
        command_name.gsub('-','_')
      end

      def self.process(&block)
        define_method(:process, &block)
      end

      def self.arity
        instance_method(:process).arity
      end

      def arity
        self.class.arity
      end

      def pickler
        @pickler ||= Pickler.new(Dir.getwd)
      end

      def abort(message)
        raise Error, message
      end

      def too_many
        abort "too many arguments"
      end

      def run
        self.class.options.each do |arguments|
          @opts.on(*arguments, &method("option_#{arguments.object_id}"))
        end
        begin
          @opts.parse!(@argv)
        rescue OptionParser::InvalidOption
          abort $!.message
        end
        return @exit if @exit
        minimum = arity < 0 ? -1 - arity : arity
        if arity >= 0 && arity < @argv.size
          too_many
        elsif minimum > @argv.size
          abort "not enough arguments"
        end
        process(*@argv)
      end

      def process(*argv)
        pickler.send(self.class.method_name,*argv)
      end

      def color?
        case pickler.config["color"]
        when "always" then true
        when "never"  then false
        else
          @tty && RUBY_PLATFORM !~ /mswin|mingw/
        end
      end

      def puts_summary(story)
        summary = "%6d " % story.id
        type  = story.estimate || TYPE_SYMBOLS[story.story_type]
        state = STATE_SYMBOLS[story.current_state]
        if color?
          summary << "\e[3#{STATE_COLORS[story.current_state]}m#{state}\e[00m "
          summary << "\e[01;3#{TYPE_COLORS[story.story_type]}m#{type}\e[00m "
        else
          summary << "#{state} #{type} "
        end
        summary << story.name
        puts summary
      end

      def paginated_output
        stdout = $stdout
        if @tty && pager = pickler.config["pager"]
          # Modeled after git
          ENV["LESS"] ||= "FRSX"
          IO.popen(pager,"w") do |io|
            $stdout = io
            yield
          end
        else
          yield
        end
      ensure
        $stdout = stdout
      end

    end

    def self.[](command)
      klass_name = command.to_s.capitalize.gsub(/[-_](.)/) { $1.upcase }
      if klass_name =~ /^[A-Z]\w*$/ && const_defined?(klass_name)
        klass = const_get(klass_name)
        if Class === klass && klass < Base
          return klass
        end
      end
    end

    def self.commands
      constants.map {|c| Runner.const_get(c)}.select {|c| Class === c && c < Runner::Base}.sort_by {|r| r.command_name}.uniq
    end

    def self.command(name, &block)
      const_set(name.to_s.capitalize.gsub(/[-_](.)/) { $1.upcase },Class.new(Base,&block))
    end

    command :show do
      banner_arguments "<story>"
      description <<-EOF
Show details for the story.
      EOF

      process do |*args|
        case args.size
        when 0
          puts "#{pickler.project_id} #{pickler.project.name}"
        when 1
          story = pickler.project.story(args.first)
          paginated_output do
            puts story
          end
        else
          too_many
        end
      end
    end

    command :search do
      banner_arguments "[query]"
      description <<-EOF
List all stories matching the given query.
      EOF

      def modifications
        @modifications ||= {}
      end
      [:label, :type, :state].each do |o|
        on "--#{o} #{o.to_s.upcase}" do |value|
          modifications[o] = value
        end
      end
      [:requester, :owner, :mywork].each do |o|
        on "--#{o} USERNAME" do |value|
          modifications[o] = value
        end
      end
      on "--[no-]includedone", "include accepted stories" do |value|
        modifications[:includedone] = value
      end

      attr_writer :current
      on "-c", "--current", "filter results to current iteration" do |b|
        self.current = b
      end

      process do |*argv|
        argv << modifications unless modifications.empty?
        if argv == [{:includedone => true}]
          # Bypass the 200 search results limitation
          stories = pickler.project.stories
        else
          stories = pickler.project.stories(*argv)
        end
        stories.reject! {|s| !s.current?} if argv.empty? || @current
        paginated_output do
          stories.each do |story|
            puts_summary story
          end
        end
      end
    end

    command :push do
      banner_arguments "[story] ..."
      description <<-EOF
Upload the given story or all features with a tracker url in a comment on the
first line.
      EOF
    end

    command :pull do
      banner_arguments "[story] ..."
      description <<-EOF
Download the given story or all well formed stories to the features/ directory.
Previously unseen stories will be given a numeric filename that you are
encouraged to change.
      EOF
    end

    command :start do
      banner_arguments "<story> [basename]"
      description <<-EOF
Pull a given feature and change its state to started.  If basename is given
and no local file exists, features/basename.feature will be created in lieu
of features/id.feature.
      EOF

      process do |story_id, *args|
        pickler.start(story_id, args.first)
      end
    end

    command :finish do
      banner_arguments "<story>"
      description <<-EOF
Push a given feature and change its state to finished.
      EOF

      process do |story_id|
        super
      end
    end

    command :deliver do
      banner_arguments "[story] ..."
      description <<-EOF
Deliver stories.
      EOF
      on "--all-finished", "deliver all finished stories" do
        @all = true
      end
      process do |*args|
        if @all
          pickler.deliver_all_finished_stories
        end
        args.each do |arg|
          pickler.story(arg).transition!('delivered')
        end
      end
    end

    command :browse do
      banner_arguments "[story]"
      description <<-EOF
Open project or a story in the web browser.

Requires launchy (gem install launchy).
      EOF

      on "--dashboard" do
        @special = "dashboard"
      end
      on "--faq" do
        @special = "help"
      end
      on "--profile", "get your API Token here" do
        @special = "profile"
      end
      on "--time", "not publicly available" do
        @special = "time_shifts"
      end

      process do |*args|
        too_many if args.size > 1 || @special && args.first
        if args.first
          url = pickler.story(args.first).url
        elsif @special
          url = "http://www.pivotaltracker.com/#@special"
        else
          url = "http://www.pivotaltracker.com/projects/#{pickler.project_id}/stories"
        end
        require 'launchy'
        Launchy.open(url)
      end
    end

    def initialize(argv)
      @argv = argv
    end

    COLORS = {
      :black   => 0,
      :red     => 1,
      :green   => 2,
      :yellow  => 3,
      :blue    => 4,
      :magenta => 5,
      :cyan    => 6,
      :white   => 7
    }

    STATE_COLORS = {
      nil           => COLORS[:black],
      "rejected"    => COLORS[:red],
      "accepted"    => COLORS[:green],
      "delivered"   => COLORS[:yellow],
      "unscheduled" => COLORS[:white],
      "started"     => COLORS[:magenta],
      "finished"    => COLORS[:cyan],
      "unstarted"   => COLORS[:blue]
    }

    STATE_SYMBOLS = {
      "unscheduled" => "  ",
      "unstarted"   => ":|",
      "started"     => ":/",
      "finished"    => ":)",
      "delivered"   => ";)",
      "rejected"    => ":(",
      "accepted"    => ":D"
    }

    TYPE_COLORS = {
      'chore'   => COLORS[:blue],
      'feature' => COLORS[:magenta],
      'bug'     => COLORS[:red],
      'release' => COLORS[:cyan]
    }

    TYPE_SYMBOLS = {
      "feature" => "*",
      "chore"   => "%",
      "release" => "!",
      "bug"     => "/"
    }

    def run
      command = @argv.shift
      if klass = self.class[command]
        result = klass.new(@argv).run
        exit result.respond_to?(:to_int) ? result.to_int : 0
      elsif ['help', '--help', '-h', '', nil].include?(command)
        puts "Run pickler <command> --help for help with a given command"
        puts "Available commands: #{self.class.commands.map {|c|c.command_name}.join(', ')}"
      else
        raise Error, "Unknown pickler command #{command}"
        exit 1
      end
    rescue Pickler::Error
      $stderr.puts "#$!"
      exit 1
    rescue Interrupt
      $stderr.puts "Interrupted!"
      exit 130
    end

  end
end
