# frozen_string_literal: true

require "prism"

module MonolithLens
  module Static
    # Entry point for static analysis of a piece of Ruby source.
    #
    # Parses the source into a Prism AST and walks it with ConstantVisitor to
    # collect dependency Edges. It never executes the analysed code.
    #
    # If the source has a syntax error, it returns no edges instead of raising,
    # so a single unparseable file cannot crash an entire scan.
    class SourceAnalyzer
      def self.analyze(source, source_file:)
        new(source, source_file: source_file).analyze
      end

      def initialize(source, source_file:)
        @source = source
        @source_file = source_file
      end

      def analyze
        result = Prism.parse(@source)
        return [] unless result.success?

        visitor = ConstantVisitor.new(source_file: @source_file)
        result.value.accept(visitor)
        visitor.edges
      end
    end
  end
end
