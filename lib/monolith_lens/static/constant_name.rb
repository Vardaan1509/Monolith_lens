# frozen_string_literal: true

require "prism"

module MonolithLens
  module Static
    # Reconstructs a String name from a Prism constant node.
    # ConstantReadNode(:User) becomes "User".
    # ConstantPathNode(parent: Accounts, :User) becomes "Accounts::User".
    module ConstantName
      module_function

      def call(node)
        case node
        when Prism::ConstantReadNode
          node.name.to_s
        when Prism::ConstantPathNode
          parent = node.parent ? call(node.parent) : nil
          [parent, node.name.to_s].compact.join("::")
        end
      end
    end
  end
end
