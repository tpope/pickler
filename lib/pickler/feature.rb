class Pickler
  class Feature
    URL_REGEX = %r{\bhttps?://www\.pivotaltracker\.com/\S*/(\d+)\b}
    attr_reader :pickler

    def initialize(pickler, identifier)
      @pickler = pickler
      case identifier
      when nil, /^\s+$/
        raise Error, "No feature given"

      when Pickler::Tracker::Story
        @story = identifier
        @id = @story.id

      when Integer
        @id = identifier

      when /^#{URL_REGEX}$/, /^(\d+)$/
        @id = $1.to_i

      when /\.feature$/
        if File.exist?(identifier)
          @filename = identifier
        end

      else
        if File.exist?(path = pickler.features_path("#{identifier}.feature"))
          @filename = path
        end

      end or raise Error, "Unrecognizable feature #{identifier}"
    end

    def local_body
      File.read(filename) if filename
    end

    def filename
      unless defined?(@filename)
        @filename = Dir[pickler.features_path("**","*.feature")].detect do |f|
          File.read(f)[/(?:#\s*|@[[:punct:]]?)#{URL_REGEX}/,1].to_i == @id
        end
      end
      @filename
    end

    def to_s
      local_body || story.to_s(pickler.format)
    end

    def pull(default = nil)
      story = story() # force the read into local_body before File.open below blows it away
      filename = filename() || pickler.features_path("#{story.suggested_basename(default)}.feature")
      File.open(filename,'w') {|f| f.puts story.to_s(pickler.format)}
      @filename = filename
    end

    def start(default = nil)
      story.transition!("started") if story.startable?
      if filename || default
        pull(default)
      end
    end

    def pushable?
      id || local_body =~ %r{\A(?:#\s*|@[[:punct:]]?(?:https?://www\.pivotaltracker\.com/story/new)?[[:punct:]]?(?:\s+@\S+)*\s*)\n[[:upper:]][[:lower:]]+:} ? true : false
    end

    def push
      body = local_body
      if story
        return if story.to_s(pickler.format) == body.to_s
        story.to_s = body
        story.save!
      else
        unless pushable?
          raise Error, "To create a new story, tag it @http://www.pivotaltracker.com/story/new"
        end
        story = pickler.new_story
        story.to_s = body
        @story = story.save!
        unless body.sub!(%r{\bhttps?://www\.pivotaltracker\.com/story/new\b}, story.url)
          body.sub!(/\A(?:#.*\n)?/,"# #{story.url}\n")
        end
        File.open(filename,'w') {|f| f.write body}
      end
    end

    def finish
      if filename
        story.finish
        story.to_s = local_body
        story.save
      else
        story.finish!
      end
    end

    def id
      unless defined?(@id)
        @id = if id = local_body.to_s[/(?:#\s*|@[[:punct:]]?)#{URL_REGEX}/,1]
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
