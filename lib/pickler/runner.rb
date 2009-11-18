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

      def self.summary(value = nil)
        if value
          @summary = value
        else
          @summary
        end
      end

      def self.description(value = nil)
        if value
          @description = value
        else
          @description || "#@summary."
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

      def colorize(code, string)
        if color?
          "\e[#{code}m#{string}\e[00m"
        else
          string.to_s
        end
      end

      def puts_summary(story)
        summary = "%6d " % story.id
        type  = story.estimate || TYPE_SYMBOLS[story.story_type]
        state = STATE_SYMBOLS[story.current_state]
        summary << colorize("3#{STATE_COLORS[story.current_state]}", state) << ' '
        summary << colorize("01;3#{TYPE_COLORS[story.story_type]}", type) << ' '
        summary << story.name
        puts summary
      end

      def puts_full(story)
        puts colorize("01;3#{TYPE_COLORS[story.story_type]}", story.name)
        puts "Type:      #{story.story_type}".rstrip
        if story.story_type == "release"
          puts "Deadline:  #{story.deadline}".rstrip
        else
          puts "Estimate:  #{story.estimate}".rstrip
        end
        puts "State:     #{story.current_state}".rstrip
        puts "Labels:    #{story.labels.join(', ')}".rstrip
        puts "Requester: #{story.requested_by}".rstrip
        puts "Owner:     #{story.owned_by}".rstrip
        puts "URL:       #{story.url}".rstrip
        puts unless story.description.blank?
        story.description_lines.each do |line|
          puts "  #{line}".rstrip
        end
        story.notes.each do |note|
          puts
          puts "  #{colorize('01', note.author)} (#{note.date})"
          puts *note.lines(72).map {|l| "    #{l}".rstrip}
        end
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
      rescue Errno::EPIPE
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
      summary "Show details for a story"

      on "--full", "default format" do
        @format = :full
      end

      on "--raw", "same as the .feature" do
        @format = :raw
      end

      process do |*args|
        case args.size
        when 0
          puts "#{pickler.project_id} #{pickler.project.name}"
        when 1
          feature = pickler.feature(args.first)
          story = feature.story
          case @format
          when :raw
            puts feature.story.to_s(pickler.format) if feature.story
          else
            paginated_output do
              puts_full feature.story
            end
          end
        else
          too_many
        end
      end
    end

    command :search do
      banner_arguments "[query]"
      summary "List all stories matching a query"

      def modifications
        @modifications ||= {}
      end
      [:label, :type, :state].each do |o|
        on "--#{o} #{o.to_s.upcase}" do |value|
          modifications[o] = value
        end
      end
      [:requester, :owner, :mywork].each do |o|
        on "--#{o}[=USERNAME]" do |value|
          modifications[o] = value || pickler.real_name
        end
      end
      on "--[no-]includedone", "include accepted stories" do |value|
        modifications[:includedone] = value
        @iterations ||= []
        @iterations << :done?
      end

      on "-b", "--backlog", "filter results to future iterations" do |c|
        @iterations ||= []
        @iterations << :backlog?
      end

      on "-c", "--current", "filter results to current iteration" do |b|
        @iterations ||= []
        @iterations << :current?
      end

      on "--[no-]full", "show full story, not a summary line" do |b|
        @full = b
      end

      process do |*argv|
        argv << modifications unless modifications.empty?
        if argv == [{:includedone => true}]
          # Bypass the 200 search results limitation
          stories = pickler.project.stories
        else
          stories = pickler.project.stories(*argv)
        end
        if @iterations && @iterations != [:done?]
          stories.reject! {|s| !@iterations.any? {|i| s.send(i)}}
        end
        paginated_output do
          first = true
          stories.each do |story|
            if @full
              puts unless first
              puts_full story
            else
              puts_summary story
            end
            first = false
          end
        end
      end
    end

    command :push do
      banner_arguments "[story] ..."
      summary "Upload stories"
      description <<-EOF
Upload the given story or all features with a tracker url in a comment on the
first line.  Features with a blank comment in the first line will created as
new stories.
      EOF

      process do |*args|
        args.replace(pickler.local_features) if args.empty?
        args.each do |arg|
          pickler.feature(arg).push
        end
      end
    end

    command :pull do
      banner_arguments "[story] ..."
      summary "Download stories"
      description <<-EOF
Download the given story or all well formed stories to the features/ directory.
      EOF

      process do |*args|
        args.replace(pickler.scenario_features) if args.empty?
        args.each do |arg|
          pickler.feature(arg).pull
        end
      end
    end

    command :start do
      banner_arguments "<story> [basename]"
      summary "Pull a story and mark it started"
      description <<-EOF
Pull a given story and change its state to started.  If basename is given
and no local file exists, features/basename.feature will be created.  Give a
basename of "-" to use a downcased, underscored version of the story name as
the basename.
      EOF

      process do |story, *args|
        pickler.feature(story).start(args.first)
      end
    end

    command :finish do
      banner_arguments "<story>"
      summary "Push a story and mark it finished"

      process do |story|
        pickler.feature(story).finish
      end
    end

    command :deliver do
      banner_arguments "[story] ..."
      summary "Mark stories delivered"
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

    command :unstart do
      banner_arguments "[story] ..."
      summary "Mark stories unstarted"
      on "--all-started", "unstart all started stories" do
        @all = true
      end
      process do |*args|
        if @all
          pickler.project.stories(:state => "started").each do |story|
            story.transition!('unstarted')
          end
        end
        args.each do |arg|
          pickler.story(arg).transition!('unstarted')
        end
      end
    end

    command :unschedule do
      banner_arguments "[story] ..."
      summary "Move stories to icebox"
      process do |*args|
        args.each do |arg|
          pickler.story(arg).transition!('unscheduled')
        end
      end
    end

    command :browse do
      banner_arguments "[story]"
      summary "Open a story in the web browser"
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
        @special = "time_shifts?project=#{pickler.project_id}"
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

    command :comment do
      banner_arguments "<story> <paragraph> ..."
      summary "Post a comment to a story"

      process do |story, *paragraphs|
        pickler.story(story).comment!(paragraphs.join("\n\n"))
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
        puts "usage: pickler <command> [options] [arguments]"
        puts
        puts "Commands:"
        self.class.commands.each do |command|
          puts "    %-19s %s" % [command.command_name, command.summary]
        end
        puts
        puts "Run pickler <command> --help for help with a given command"
      else
        raise Error, "Unknown pickler command #{command}"
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
