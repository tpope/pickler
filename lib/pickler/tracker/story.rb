class Pickler
  class Tracker
    class Story < Abstract

      TYPES = %w(bug feature chore release)
      STATES = %w(unscheduled unstarted started finished delivered rejected accepted)

      attr_reader :project
      reader :iteration, :url, :labels
      date_reader :created_at, :accepted_at, :deadline
      accessor :current_state, :name, :description, :estimate, :owned_by, :requested_by, :story_type

      def initialize(project, attributes = {})
        @project = project
        super(attributes)
      end

      def transition!(state)
        raise Pickler::Tracker::Error, "Invalid state #{state}", caller unless STATES.include?(state)
        self.current_state = state
        if id
          xml = "<story><current-state>#{state}</current-state></story>"
          error = tracker.request_xml(:put, resource_url, xml).fetch("errors",{})["error"] || true
        else
          error = save
        end
        raise Pickler::Tracker::Error, Array(error).join("\n"), caller unless error == true
      end

      def complete?
        %w(finished delivered accepted).include?(current_state)
      end

      def startable?
        %w(unscheduled unstarted rejected).include?(current_state)
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

      def comment!(body)
        raise ArgumentError if body.strip.empty? || body.size > 5000
        response = tracker.request_xml(:post, "#{resource_url}/notes",{:text => body}.to_xml(:root => 'note'))
        Note.new(self, response["note"])
      end

      def to_xml
        hash = @attributes.except("id","url","iteration","notes","labels")
        hash["labels"] = Array(@attributes["labels"]).join(", ")
        hash.to_xml(:root => "story")
      end

      def destroy
        if id
          response = tracker.request_xml(:delete, "/projects/#{project.id}/stories/#{id}", to_xml)
          raise Error, response["message"], caller if response["success"] != "true"
          @attributes["id"] = nil
          self
        end
      end

      def resource_url
        ["/projects/#{project.id}/stories",id].compact.join("/")
      end

      def save
        response = tracker.request_xml(id ? :put : :post,  resource_url, to_xml)
        if response["success"] == "true"
          initialize(project, response["story"])
          true
        else
          Array(response["errors"]["error"])
        end
      end

    end
  end
end
