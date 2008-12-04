class Pickler
  class Runner

    attr_reader :pickler, :argv

    def initialize(argv)
      @argv = argv
      @pickler = Pickler.new(Dir.getwd)
    end

    def run
      case first = argv.shift
      when 'show', /^\d+$/
        story = pickler.project.story(first == 'show' ? argv.shift : first)
        puts story
      when 'search'
        stories = pickler.project.stories(*argv).group_by {|s| s.current_state}
        first = true
        states = Pickler::Tracker::Story::STATES
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
        pickler.start(argv.first,argv[1])
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

  end
end
