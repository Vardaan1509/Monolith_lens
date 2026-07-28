# frozen_string_literal: true

require "prism"

module MonolithLens
  module Static
    # Walks a Prism AST and collects dependency Edges from a single Ruby file.
    #
    # Detects class inheritance, mixins (include/prepend/extend), and
    # qualified constant references (Foo::Bar). Bare constants like String
    # or MAX_SIZE are skipped for now - telling app code apart from a Ruby
    # built-in needs a whole-repo symbol table we don't have yet.
    #
    # Constant references are tagged by how confident we are: used as a call
    # receiver (Foo::Bar.find) is stronger evidence than used as a plain
    # value (x = Foo::Bar). Neither is dropped; confidence scoring decides
    # later how much to trust each one.
    class ConstantVisitor < Prism::Visitor
      MIXIN_METHODS = %i[include prepend extend].freeze

      attr_reader :edges

      def initialize(source_file:)
        super()
        @source_file = source_file
        @namespace = []
        @edges = []
        @handled = Set.new
      end

      def visit_module_node(node)
        mark_handled(node.constant_path)
        @namespace.push(ConstantName.call(node.constant_path))
        super
        @namespace.pop
      end

      def visit_class_node(node)
        mark_handled(node.constant_path)
        mark_handled(node.superclass)
        @namespace.push(ConstantName.call(node.constant_path))
        record_inheritance(node.superclass) if node.superclass
        super
        @namespace.pop
      end

      def visit_call_node(node)
        if mixin_call?(node)
          record_mixins(node)
        elsif qualified_constant?(node.receiver)
          mark_handled(node.receiver)
          record_reference(node.receiver, rule: "constant_reference_call")
        end
        super
      end

      # No super here: a constant path's only child is its own parent chain,
      # and descending would double-count sub-paths (A::B inside A::B::C).
      def visit_constant_path_node(node)
        record_reference(node, rule: "constant_reference_value") unless handled?(node)
      end

      private

      def mixin_call?(node)
        node.receiver.nil? && MIXIN_METHODS.include?(node.name)
      end

      def qualified_constant?(node)
        node.is_a?(Prism::ConstantPathNode)
      end

      def record_inheritance(superclass_node)
        @edges << build_edge(
          target: ConstantName.call(superclass_node),
          dependency_type: :inheritance,
          rule: "class_inheritance",
          line: superclass_node.location.start_line
        )
      end

      def record_mixins(node)
        return if @namespace.empty?

        constant_arguments(node).each do |argument|
          mark_handled(argument)
          @edges << build_edge(
            target: ConstantName.call(argument),
            dependency_type: node.name,
            rule: "module_#{node.name}",
            line: argument.location.start_line
          )
        end
      end

      def record_reference(node, rule:)
        return if @namespace.empty?

        target = ConstantName.call(node)
        return if target.nil? || target == current_source

        @edges << build_edge(
          target: target,
          dependency_type: :constant_reference,
          rule: rule,
          line: node.location.start_line
        )
      end

      def constant_arguments(node)
        (node.arguments&.arguments || []).select { |arg| ConstantName.call(arg) }
      end

      # object_id lets us recognize the same AST node reached two ways
      # (e.g. as a superclass, then again via the generic walk) so it is
      # only recorded once.
      def mark_handled(node)
        @handled << node.object_id if node
      end

      def handled?(node)
        @handled.include?(node.object_id)
      end

      def current_source
        @namespace.join("::")
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
