# frozen_string_literal: true

require "json"
require "thor"
require_relative "../monolith_lens"

module MonolithLens
  # Command-line interface for MonolithLens. Kept thin: each command
  # validates input, calls into the core library, and formats the result.
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    desc "scan PATH", "Statically analyze Ruby files under PATH and print dependency edges as JSON"
    def scan(path)
      abort_unless_exists(path)

      result = MonolithLens::Static::Scanner.scan(path)
      warn "Scanned #{result.files_scanned} file(s); found #{result.edges.length} edge(s)."
      puts JSON.pretty_generate(edges_as_json(result.edges))
    end

    desc "boundaries CODE_PATH", "Classify dependencies against Packwerk packages; report violations and cycles"
    method_option :app_root, type: :string,
                             desc: "App root containing package.yml files (defaults to CODE_PATH)"
    def boundaries(code_path)
      abort_unless_exists(code_path)

      result = MonolithLens::Analysis::PackageAnalysis.call(
        code_path: code_path, app_root: options[:app_root] || code_path
      )
      warn boundaries_summary(result)
      puts JSON.pretty_generate(boundaries_json(result))
    end

    private

    def abort_unless_exists(path)
      return if File.exist?(path)

      warn "monolith-lens: path not found: #{path}"
      exit 1
    end

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

    def boundaries_json(result)
      {
        summary: classification_counts(result.classified_edges),
        cycles: result.cycles,
        boundary_violations: violations_json(result.classified_edges)
      }
    end

    def classification_counts(classified_edges)
      classified_edges.each_with_object(Hash.new(0)) do |classified_edge, counts|
        counts[classified_edge.classification] += 1
      end
    end

    def violations_json(classified_edges)
      classified_edges.select { |ce| ce.classification == :boundary_violation }.map do |ce|
        evidence = ce.edge.evidence.first
        {
          source: ce.edge.source, target: ce.edge.target,
          source_package: ce.source_package, target_package: ce.target_package,
          file: evidence.source_file, line: evidence.line
        }
      end
    end

    def boundaries_summary(result)
      violations = result.classified_edges.count { |ce| ce.classification == :boundary_violation }
      "Analyzed #{result.classified_edges.length} edge(s); " \
        "#{violations} violation(s), #{result.cycles.length} cycle(s)."
    end
  end
end
