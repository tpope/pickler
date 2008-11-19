class Pickler
  class Tracker
    class Story < Abstract

      TYPES = %w(bug feature chore release)
      STATES = %w(unstarted started finished delivered rejected accepted)

      attr_reader :project
      reader :created_at, :iteration, :url, :labels
      accessor :current_state, :name, :description, :estimate, :owned_by, :requested_by, :story_type

      def initialize(project, attributes = {})
        @project = project
        super(attributes)
      end

      def tracker
        project.tracker
      end

      def to_s
        to_s = "# #{url}\n#{story_type.capitalize}: #{name}\n"
        description_lines.each do |line|
          to_s << "  #{line}".rstrip << "\n"
        end
        to_s
      end

      def to_s=(body)
        body = body.sub(/\A# .*\n/,'')
        if body =~ /\A(\w+): (.*)/
          self.story_type = $1.downcase
          self.name = $2
          description = $'
        else
          self.story_type = "feature"
          self.name = body[/.*/]
          description = $'
        end
        self.description = description.gsub(/\A\n+|\n+\Z/,'') + "\n"
        if description_lines.all? {|l| l.empty? || l =~ /^  /}
          self.description.gsub!(/^  /,'')
        end
        self
      end

      def description_lines
        array = []
        description.to_s.each_line do |line|
          array << line.chomp
        end
        array
      end

      def notes
        [@attributes["notes"]].flatten.compact
      end

      def to_xml
        hash = @attributes.except("id","url","iteration","notes","labels")
        hash["labels"] = Array(@attributes["labels"]).join(", ")
        hash.to_xml(:root => "story")
      end

      def destroy
        if id
          request = tracker.request_xml(:delete, "/projects/#{project.id}/stories/#{id}", to_xml)
          raise Error, request["message"], caller if request["success"] != "true"
          @attributes["id"] = nil
          self
        end
      end

      def save
        if id
          request = tracker.request_xml(:put, "/projects/#{project.id}/stories/#{id}", to_xml)
        else
          request = tracker.request_xml(:post, "/projects/#{project.id}/stories", to_xml)
        end
        if request["success"] == "true"
          initialize(project, request["story"])
          true
        else
          Array(request["errors"]["error"])
        end
      end

    end
  end
end
