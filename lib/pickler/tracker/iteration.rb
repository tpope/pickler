class Pickler
  class Tracker
    class Iteration < Abstract
      attr_reader :project
      date_reader :start, :finish

      def initialize(project, attributes = {})
        @project = project
        super(attributes)
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
        self.class.new(project, 'number' => number.succ.to_s, 'start' => @attributes['finish'], 'finish' => (finish + (finish - start)).strftime("%b %d, %Y"))
      end

      def inspect
        "#<#{self.class.inspect}:#{number.inspect} (#{range.inspect})>"
      end
    end
  end
end
