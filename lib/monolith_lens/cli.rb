# frozen_string_literal: true

require "json"
require "thor"
require_relative "../monolith_lens"

module MonolithLens
  # Command-line interface for MonolithLens.
  #
  # Kept deliberately thin: each command validates input, calls into the core
  # library, and formats the result. No analysis logic lives here.
  class CLI < Thor
    # Tell Thor to exit with a non-zero status when a command fails, instead of
    # swallowing the error (also silences a Thor deprecation warning).
    def self.exit_on_failure?
      true
    end

    desc "scan PATH", "Statically analyze Ruby files under PATH and print dependency edges as JSON"
    def scan(path)
      unless File.exist?(path)
        warn "monolith-lens: path not found: #{path}"
        exit 1
      end

      result = MonolithLens::Static::Scanner.scan(path)
      warn "Scanned #{result.files_scanned} file(s); found #{result.edges.length} edge(s)."
      puts JSON.pretty_generate(edges_as_json(result.edges))
    end

    private

    def edges_as_json(edges)
      edges.map do |edge|
        {
          source: edge.source,
          target: edge.target,
          dependency_type: edge.dependency_type,
          evidence: edge.evidence.map(&:to_h)
        }
      end
    end
  end
end
