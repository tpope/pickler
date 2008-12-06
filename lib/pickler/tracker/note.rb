class Pickler
  class Tracker
    class Note < Abstract
      attr_reader :story
      reader :text, :author
      date_reader :date

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

    end
  end
end
