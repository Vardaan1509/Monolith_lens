# frozen_string_literal: true

module MonolithLens
  module Analysis
    # Boundary analysis end-to-end: scan the code, load the Packwerk packages,
    # classify every edge, and detect package-level dependency cycles.
    #
    # `code_path` is the directory of code to analyze; `app_root` is where the
    # package.yml files live (paths are resolved relative to it).
    class PackageAnalysis
      Result = Data.define(:classified_edges, :cycles)

      def self.call(code_path:, app_root:)
        new(code_path: code_path, app_root: app_root).call
      end

      def initialize(code_path:, app_root:)
        @code_path = code_path
        @app_root = app_root
      end

      def call
        scan = Static::Scanner.scan(@code_path, base: @app_root)
        package_set = Packwerk::PackageSet.load(@app_root)
        classified = EdgeClassifier.new(package_set, scan.definitions).classify_all(scan.edges)

        Result.new(classified_edges: classified, cycles: detect_cycles(classified))
      end

      private

      def detect_cycles(classified_edges)
        adjacency = Hash.new { |hash, key| hash[key] = [] }
        classified_edges.each do |classified_edge|
          next unless cross_package?(classified_edge)

          adjacency[classified_edge.source_package] << classified_edge.target_package
        end
        PackageGraph.new(adjacency).cycles
      end

      def cross_package?(classified_edge)
        source = classified_edge.source_package
        target = classified_edge.target_package
        !source.nil? && !target.nil? && source != target &&
          classified_edge.classification != :external
      end
    end
  end
end
