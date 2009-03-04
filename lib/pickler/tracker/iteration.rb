class Pickler
  class Tracker
    class Iteration < Abstract
      attr_reader :project

      def initialize(project, attributes = {})
        @project = project
        super(attributes)
      end

      def start
        Date.parse(@attributes['start'].to_s)
      end

      def finish
        Date.parse(@attributes['finish'].to_s)
      end

      def number
        @attributes['number'].to_i
      end
      alias to_i number

      def range
        start...finish
      end

      def include?(date)
        range.include?(date)
      end

      def succ
        self.class.new(project, 'number' => number.succ.to_s, 'start' => @attributes['finish'], 'finish' => (finish + (finish - start)))
      end

      def inspect
        "#<#{self.class.inspect}:#{number.inspect} (#{range.inspect})>"
      end

      def to_s
        "#{number} (#{start}...#{finish})"
      end
    end
  end
end
