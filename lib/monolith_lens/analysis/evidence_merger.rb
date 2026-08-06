# frozen_string_literal: true

module MonolithLens
  module Analysis
    # Merges static edges and runtime edges into MergedEdges, grouping by
    # (source, target). Each merged edge is classified by which evidence
    # sources agree and given a deterministic, documented confidence score.
    #
    # Confidence formula (0..1):
    # - static_and_runtime          => 1.0  (both sources agree)
    # - runtime_only                => 0.7  (real, but static can't see it)
    # - static_only, strong rule    => 0.85 (inheritance / include / prepend / extend)
    # - static_only, call receiver  => 0.7  (Foo::Bar.method)
    # - static_only, plain value    => 0.5  (x = Foo::Bar)
    class EvidenceMerger
      STRONG_STATIC_RULES = %w[
        class_inheritance module_include module_prepend module_extend
      ].freeze

      def self.merge(static_edges:, runtime_edges:)
        new.merge(static_edges: static_edges, runtime_edges: runtime_edges)
      end

      def merge(static_edges:, runtime_edges:)
        (static_edges + runtime_edges)
          .group_by { |edge| [edge.source, edge.target] }
          .map { |(source, target), edges| build(source, target, edges) }
      end

      private

      def build(source, target, edges)
        evidence = edges.flat_map(&:evidence)
        classification = classify(evidence)

        MergedEdge.new(
          source: source,
          target: target,
          classification: classification,
          evidence: evidence,
          confidence: confidence(classification, evidence)
        )
      end

      def classify(evidence)
        kinds = evidence.map(&:kind).uniq
        return :static_and_runtime if kinds.include?(:static) && kinds.include?(:runtime)
        return :runtime_only unless kinds.include?(:static)

        :static_only
      end

      def confidence(classification, evidence)
        case classification
        when :static_and_runtime then 1.0
        when :runtime_only then 0.7
        else static_strength(evidence)
        end
      end

      def static_strength(evidence)
        rules = evidence.select { |e| e.kind == :static }.map(&:rule)
        return 0.85 if rules.intersect?(STRONG_STATIC_RULES)
        return 0.7 if rules.include?("constant_reference_call")

        0.5
      end
    end
  end
end
