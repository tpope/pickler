class Pickler
  class Feature
    URL_REGEX = %r{\bhttp://www\.pivotaltracker\.com/\S*/(\d+)\b}
    attr_reader :pickler

    def initialize(pickler, identifier)
      @pickler = pickler
      case identifier
      when nil, /^\s+$/
        raise Error, "No feature given"

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

      end or raise Error, "Unrecogizable feature #{string}"
    end

    def local_body
      File.read(@filename) if @filename
    end

    def filename
      unless defined?(@filename)
        @filename = Dir[pickler.features_path("**","*.feature")].detect do |f|
          File.read(f)[/#\s*#{URL_REGEX}/,1].to_i == @id
        end
      end
      @filename
    end

    def to_s
      local_body || story.to_s
    end

    def push
      return if story.to_s == local_body.to_s
      story.to_s = local_body
      story.save
    end

    def finish
      story.current_state = "finished" unless story.complete?
      story.to_s = local_body
      story.save
    end

    def id
      unless defined?(@id)
        @id = if id = local_body.to_s[/#\s*#{URL_REGEX}/,1]
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
