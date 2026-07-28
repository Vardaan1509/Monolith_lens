# frozen_string_literal: true

require "prism"

module MonolithLens
  module Static
    # Walks a Prism AST and collects dependency Edges from a single Ruby file.
    #
    # As it descends, it keeps a stack of the enclosing module/class names so
    # each edge's `source` is the fully-qualified constant, e.g.
    # "Billing::InvoiceProcessor".
    #
    # Currently detects: class inheritance (`class Foo < Bar`).
    class ConstantVisitor < Prism::Visitor
      attr_reader :edges

      def initialize(source_file:)
        super()
        @source_file = source_file
        @namespace = []
        @edges = []
      end

      # Visited for every `module Foo ... end`.
      def visit_module_node(node)
        @namespace.push(constant_name(node.constant_path))
        super # descend into the module body
        @namespace.pop
      end

      # Visited for every `class Foo < Bar ... end`.
      def visit_class_node(node)
        @namespace.push(constant_name(node.constant_path))
        record_inheritance(node.superclass) if node.superclass
        super # descend into the class body
        @namespace.pop
      end

      private

      def record_inheritance(superclass_node)
        @edges << build_edge(
          target: constant_name(superclass_node),
          dependency_type: :inheritance,
          rule: "class_inheritance",
          line: superclass_node.location.start_line
        )
      end

      # Current fully-qualified namespace, e.g. "Billing::InvoiceProcessor".
      def current_source
        @namespace.join("::")
      end

      # Reconstruct a String name from a constant node:
      #   ConstantReadNode(:User)                    -> "User"
      #   ConstantPathNode(parent: Accounts, :User)  -> "Accounts::User"
      def constant_name(node)
        case node
        when Prism::ConstantReadNode
          node.name.to_s
        when Prism::ConstantPathNode
          parent = node.parent ? constant_name(node.parent) : nil
          [parent, node.name.to_s].compact.join("::")
        end
      end

      def build_edge(target:, dependency_type:, rule:, line:)
        Edge.new(
          source: current_source,
          target: target,
          dependency_type: dependency_type,
          evidence: [Evidence.new(kind: :static, source_file: @source_file, line: line, rule: rule)]
        )
      end
    end
  end
end
