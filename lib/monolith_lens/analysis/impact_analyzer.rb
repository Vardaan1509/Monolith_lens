# frozen_string_literal: true

module MonolithLens
  module Analysis
    # Given a scan and a set of changed files, computes the change's blast
    # radius by walking the REVERSE dependency graph (who depends on the
    # changed code), then recommends tests by file-name convention.
    class ImpactAnalyzer
      def self.call(scan:, changed_files:, spec_files:)
        new(scan: scan, spec_files: spec_files).call(changed_files)
      end

      def initialize(scan:, spec_files:)
        @spec_files = spec_files
        @reverse = build_reverse(scan.edges)
        @files_by_constant = scan.definitions.group_by(&:constant)
        @constants_by_file = scan.definitions.group_by(&:source_file)
      end

      def call(changed_files)
        changed = changed_constants(changed_files)
        direct = (dependents_of(changed) - changed).uniq
        transitive = transitive_dependents(changed, direct)

        ImpactReport.new(
          changed: changed,
          directly_affected: direct,
          transitively_affected: transitive,
          recommended_tests: recommend_tests(changed + direct + transitive)
        )
      end

      private

      # target => [sources that depend on it]. If target changes, sources break.
      def build_reverse(edges)
        edges.each_with_object(Hash.new { |h, k| h[k] = [] }) do |edge, reverse|
          reverse[edge.target] << edge.source
        end
      end

      def changed_constants(changed_files)
        changed_files.flat_map { |file| (@constants_by_file[file] || []).map(&:constant) }.uniq
      end

      def dependents_of(constants)
        constants.flat_map { |constant| @reverse[constant] }.uniq
      end

      def transitive_dependents(changed, direct)
        known = (changed + direct).to_h { |constant| [constant, true] }
        walk_dependents(direct.dup, known)
      end

      def walk_dependents(queue, known)
        result = []
        until queue.empty?
          @reverse[queue.shift].each do |dependent|
            next if known[dependent]

            known[dependent] = true
            result << dependent
            queue << dependent
          end
        end
        result
      end

      def recommend_tests(constants)
        constants.filter_map { |constant| spec_for(constant) }.uniq
      end

      def spec_for(constant)
        file = @files_by_constant[constant]&.first&.source_file
        return unless file

        basename = File.basename(file, ".rb")
        spec = @spec_files.find { |path| File.basename(path) == "#{basename}_spec.rb" }
        { spec: spec, covers: constant } if spec
      end
    end
  end
end
