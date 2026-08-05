# frozen_string_literal: true

require "tsort"

module MonolithLens
  module Analysis
    # A directed graph of package -> packages. Uses stdlib TSort to find
    # dependency cycles: strongly connected components with more than one node.
    #
    # This is the insight Packwerk's per-reference check can't give on its own -
    # Packwerk reports one undeclared reference at a time; here we see the loop.
    class PackageGraph
      include TSort

      def initialize(adjacency)
        @adjacency = adjacency
      end

      def cycles
        strongly_connected_components.select { |component| component.length > 1 }
      end

      def tsort_each_node(&)
        @adjacency.each_key(&)
      end

      def tsort_each_child(node, &)
        @adjacency.fetch(node, []).each(&)
      end
    end
  end
end
