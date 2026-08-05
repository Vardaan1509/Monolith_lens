# frozen_string_literal: true

require "json"

module MonolithLens
  module Runtime
    # Reads a JSONL trace file (produced by Tracer) and converts each observed
    # event into a runtime dependency Edge. A source file is resolved to the
    # most specific constant defined in it, using the scan's definitions.
    class TraceIngester
      def self.ingest(trace_path, definitions:)
        new(definitions).ingest(trace_path)
      end

      def initialize(definitions)
        @constants_by_file = definitions.group_by(&:source_file)
      end

      def ingest(trace_path)
        return [] unless File.exist?(trace_path)

        lines(trace_path).map { |line| edge_from(JSON.parse(line)) }
      end

      private

      def lines(trace_path)
        File.readlines(trace_path, chomp: true).reject(&:empty?)
      end

      def edge_from(event)
        Edge.new(
          source: source_constant(event["source_file"]),
          target: event["target"],
          dependency_type: event["type"].to_sym,
          evidence: [evidence_for(event)]
        )
      end

      def evidence_for(event)
        Evidence.new(
          kind: :runtime,
          source_file: event["source_file"],
          line: event["source_line"],
          rule: event["type"]
        )
      end

      # The most specific constant defined in a file (the leaf class), or the
      # file path itself if we have no definition for it.
      def source_constant(source_file)
        defined = @constants_by_file[source_file]&.map(&:constant) || []
        defined.max_by(&:length) || source_file
      end
    end
  end
end
