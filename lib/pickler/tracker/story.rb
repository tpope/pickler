class Pickler
  class Tracker
    class Story < Abstract

      TYPES = %w(bug feature chore release)
      STATES = %w(unscheduled unstarted started finished delivered rejected accepted)

      attr_reader :project, :labels
      reader :url
      date_reader :created_at, :updated_at, :accepted_at, :deadline
      accessor :current_state, :name, :description, :owned_by, :requested_by, :story_type

      def initialize(project, attributes = {})
        @project = project
        @labels = []
        super(attributes)
        @iteration = Iteration.new(project, attributes["iteration"]) if attributes["iteration"]
      end

      def iteration
        unless current_state == 'unscheduled' || defined?(@iteration)
          @iteration = project.stories(:id => id, :includedone => true).first.iteration
        end
        @iteration
      end

      def labels=(value)
        @labels = normalize_labels(value)
      end

      def transition!(state)
        raise Pickler::Tracker::Error, "Invalid state #{state}", caller unless STATES.include?(state)
        self.current_state = state
        if id
          xml = "<story><current_state>#{state}</current_state></story>"
          error = tracker.request_xml(:put, resource_url, xml).fetch("errors",{})["error"] || true
        else
          error = save
        end
        raise Pickler::Tracker::Error, Array(error).join("\n"), caller unless error == true
      end

      def finish
        case story_type
        when "bug", "feature"
          self.current_state = "finished" unless complete?
        when "chore", "release"
          self.current_state = "accepted"
        end
        current_state
      end

      def finish!
        transition!(finish)
      end

      def backlog?(as_of = Date.today)
        iteration && iteration.start >= as_of
      end

      def current?(as_of = Date.today)
        iteration && iteration.include?(as_of)
      end

      # In a previous iteration
      def done?(as_of = Date.today)
        iteration && iteration.finish <= as_of
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

      def to_s(format = :tag)
        to_s = "#{header(format)}\n#{updated_at_annotation}\n#{story_type.capitalize}: #{name}\n"
        if description_lines.index('---')
          description_array = description_lines.each_slice(description_lines.index('---')).to_a
          top_description_lines = description_array.first # feature story
          bottom_description_lines = description_array.last # metadata

          top_description_lines.each do |line|
            to_s << "  #{line}".rstrip << "\n"
          end

          bottom_description_lines.each do |line|
            to_s << "#  #{line}".rstrip << "\n"
          end
        else
          description_lines.each do |line|
            to_s << "  #{line}".rstrip << "\n"
          end
        end
        if to_s !~ /\A[\0-\177]*\z/
          to_s = "# -*- coding: utf-8 -*-\n#{to_s}"
        end
        to_s
      end

      def header(format = :tag)
        case format
        when :tag
          "@#{url || "#{project.use_https? ? 'https' : 'http'}://www.pivotaltracker.com/story/new"}#{labels.map {|l| " @#{l.tr(' _','_,')}"}.join}"
        else
          "# #{url}"
        end
      end

      def updated_at_annotation
        "# updated_at: #{updated_at}"
      end

      def to_s=(body)
        if body =~ /\A@https?\b\S*(\s+@\S+)*\s*$/
          self.labels = body[/\A@.*/].split(/\s+/)[1..-1].map {|l| l[1..-1].tr('_,',' _')}
        end
        body = body.sub(/\A(?:[@#].*\n)+/,'')
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
        else
          push_description_lines = self.description.split("\n")

          if push_description_lines.index('#  ---')
            out = ''
            description_array = push_description_lines.each_slice(push_description_lines.index('#  ---')).to_a
            top_description_lines = description_array.first # feature story
            bottom_description_lines = description_array.last # metadata

            top_description_lines.each do |line, index|
              out << line.gsub(/^  /,'') << "\n"
            end

            bottom_description_lines.each do |line, index|
              out << line.gsub(/^#\s{0,2}/,'') << "\n"
            end

            self.description = out
          end
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
        [attributes["notes"]].flatten.compact.map {|n| Note.new(self,n)}
      end

      def estimate
        attributes["estimate"].to_i < 0 ? nil : @attributes["estimate"]
      end

      def estimate=(value)
        attributes["estimate"] = value.nil? ? -1 : value
      end

      def suggested_basename(user_override = nil)
        if user_override.to_s !~ /\A-?\z/
          user_override
        else
          name.to_s.empty? ? id.to_s : name.gsub(/[^\w-]+/,'_').downcase
        end
      end

      def comment!(body)
        response = tracker.request_xml(:post, "#{resource_url}/notes",Pickler.hash_to_xml(:note, :text => body))
        if response["note"]
          Note.new(self, response["note"])
        else
          raise Pickler::Tracker::Error, Array(response["errors"]["error"]).join("\n"), caller
        end
      end

      def to_xml(force_labels = true)
        hash = attributes.reject do |k,v|
          !%w(current_state deadline description estimate name owned_by requested_by story_type).include?(k)
        end
        if force_labels || !id || normalize_labels(attributes["labels"]) != labels
          hash["labels"] = labels.join(", ")
        end
        Pickler.hash_to_xml(:story, hash)
      end

      def destroy
        if id
          response = tracker.request_xml(:delete, "/projects/#{project.id}/stories/#{id}", "")
          raise Error, response["message"], caller if response["message"]
          attributes["id"] = nil
          self
        end
      end

      def resource_url
        ["/projects/#{project.id}/stories",id].compact.join("/")
      end

      def save
        response = tracker.request_xml(id ? :put : :post,  resource_url, to_xml(false))
        if response["story"]
          initialize(project, response["story"])
          true
        else
          Array(response["errors"]["error"])
        end
      end

      def save!
        errors = save
        if errors != true
          raise Pickler::Tracker::Error, Array(errors).join("\n"), caller
        end
        self
      end

      private
      def normalize_labels(value)
        Array(value).join(", ").strip.split(/\s*,\s*/)
      end

    end
  end
end
