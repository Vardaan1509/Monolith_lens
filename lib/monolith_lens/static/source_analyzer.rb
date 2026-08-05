# frozen_string_literal: true

require "prism"

module MonolithLens
  module Static
    # Parses Ruby source with Prism and walks it with ConstantVisitor to
    # collect dependency edges and constant definitions. Never executes the
    # analyzed code. Returns an empty FileAnalysis (instead of raising) if the
    # source has a syntax error.
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
        return FileAnalysis.new(edges: [], definitions: []) unless result.success?

        visitor = ConstantVisitor.new(source_file: @source_file)
        result.value.accept(visitor)
        FileAnalysis.new(edges: visitor.edges, definitions: visitor.definitions)
      end
    end
  end
end
