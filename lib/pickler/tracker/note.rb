class Pickler
  class Tracker
    class Note < Abstract
      attr_reader :story
      reader :text, :author
      date_reader :noted_at

      def date
        noted_at && Date.new(noted_at.year, noted_at.mon, noted_at.day)
      end

      def initialize(story, attributes = {})
        @story = story
        super(attributes)
      end

      def to_xml
        @attributes.to_xml(:dasherize => false, :root => 'note')
      end

      def inspect
        "#<#{self.class.inspect}:#{id.inspect}, story_id: #{story.id.inspect}, date: #{date.inspect}, author: #{author.inspect}, text: #{text.inspect}>"
      end

      def lines(width = 79)
        text.scan(/(?:.{0,#{width}}|\S+?)(?:\s|$)/).map! {|line| line.strip}[0..-2]
      end

    end
  end
end
