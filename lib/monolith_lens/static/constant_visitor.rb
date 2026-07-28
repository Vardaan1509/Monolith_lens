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
    # Detects:
    # - class inheritance       (`class Foo < Bar`)
    # - mixins                  (`include` / `prepend` / `extend Mod`)
    # - qualified constant refs (`Accounts::User.find`, `x = Accounts::User`)
    #
    # For constant references we favour recall over precision: every qualified
    # reference (a `Foo::Bar` path) is captured, tagged by how it was used so a
    # later confidence-scoring step can weight them:
    # - used as a call receiver -> rule "constant_reference_call"  (stronger)
    # - used any other way      -> rule "constant_reference_value" (weaker)
    #
    # Bare, unqualified constants (`String`, `MAX_SIZE`) are intentionally NOT
    # recorded yet: telling an app class apart from a Ruby built-in or a local
    # constant needs a whole-repo symbol table we do not have while analysing a
    # single file. (Documented limitation; revisit once directory scanning
    # gives repo-wide visibility.)
    class ConstantVisitor < Prism::Visitor
      MIXIN_METHODS = %i[include prepend extend].freeze

      attr_reader :edges

      def initialize(source_file:)
        super()
        @source_file = source_file
        @namespace = []
        @edges = []
        # AST nodes already accounted for elsewhere (a superclass, a mixin
        # argument, a definition name, a call receiver) so the generic
        # constant-path pass does not record them a second time.
        @handled = Set.new
      end

      # Visited for every `module Foo ... end`.
      def visit_module_node(node)
        mark_handled(node.constant_path)
        @namespace.push(ConstantName.call(node.constant_path))
        super # descend into the module body
        @namespace.pop
      end

      # Visited for every `class Foo < Bar ... end`.
      def visit_class_node(node)
        mark_handled(node.constant_path)
        mark_handled(node.superclass)
        @namespace.push(ConstantName.call(node.constant_path))
        record_inheritance(node.superclass) if node.superclass
        super # descend into the class body
        @namespace.pop
      end

      # Visited for every method call. Two things interest us: bare mixin calls
      # (`include Auditable`) and calls whose receiver is a qualified constant
      # (`Accounts::User.find`).
      def visit_call_node(node)
        if mixin_call?(node)
          record_mixins(node)
        elsif qualified_constant?(node.receiver)
          mark_handled(node.receiver)
          record_reference(node.receiver, rule: "constant_reference_call")
        end
        super
      end

      # Visited for every qualified constant (`Foo::Bar`). Anything not already
      # handled elsewhere is treated as a plain-value reference.
      def visit_constant_path_node(node)
        record_reference(node, rule: "constant_reference_value") unless handled?(node)
        # Intentionally NOT calling super: a constant path's only child is its
        # parent chain, and recording those would double-count sub-paths
        # (e.g. "A::B" inside "A::B::C"). The full name is already captured.
      end

      private

      # A bare `include`/`prepend`/`extend Foo` call (no explicit receiver).
      def mixin_call?(node)
        node.receiver.nil? && MIXIN_METHODS.include?(node.name)
      end

      # A `Foo::Bar`-style constant (as opposed to a bare `Foo` or a non-constant).
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

      # Record a qualified-constant reference edge. Skips references with no
      # enclosing class/module, and self-references.
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

      # The constant arguments of a call (e.g. the modules in `include A, B`),
      # ignoring anything dynamic like `include some_method`.
      def constant_arguments(node)
        (node.arguments&.arguments || []).select { |arg| ConstantName.call(arg) }
      end

      def mark_handled(node)
        @handled << node.object_id if node
      end

      def handled?(node)
        @handled.include?(node.object_id)
      end

      # Current fully-qualified namespace, e.g. "Billing::InvoiceProcessor".
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
