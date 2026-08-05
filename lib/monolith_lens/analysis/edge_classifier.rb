# frozen_string_literal: true

module MonolithLens
  module Analysis
    # Classifies each dependency edge relative to the Packwerk packages:
    #
    # - :external           target isn't defined in any package (a gem/framework)
    # - :internal           source and target are the same package
    # - :unchecked          source doesn't enforce dependencies (e.g. root)
    # - :declared           cross-package, and the dependency is declared
    # - :boundary_violation cross-package, enforced, and NOT declared
    class EdgeClassifier
      def initialize(package_set, definitions)
        @package_set = package_set
        @definition_index = index_definitions(definitions)
      end

      def classify_all(edges)
        edges.map { |edge| classify(edge) }
      end

      def classify(edge)
        source = @package_set.package_for(source_path(edge))
        target = target_package(edge)

        ClassifiedEdge.new(
          edge: edge,
          source_package: source&.name,
          target_package: target&.name,
          classification: classification_for(source, target)
        )
      end

      private

      # constant => defining file. A namespace module can be defined in many
      # files; any one in the owning package resolves to the same package.
      def index_definitions(definitions)
        definitions.each_with_object({}) do |defn, index|
          index[defn.constant] ||= defn.source_file
        end
      end

      def source_path(edge)
        edge.evidence.first.source_file
      end

      def target_package(edge)
        file = @definition_index[edge.target]
        file && @package_set.package_for(file)
      end

      def classification_for(source, target)
        return :external if target.nil?
        return :internal if source && source == target
        return :unchecked if source.nil? || !source.enforce_dependencies
        return :declared if @package_set.declares?(source, target)

        :boundary_violation
      end
    end
  end
end
