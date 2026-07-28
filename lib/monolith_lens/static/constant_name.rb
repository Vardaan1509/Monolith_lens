# frozen_string_literal: true

require "prism"

module MonolithLens
  module Static
    # Reconstructs a String name from a Prism constant node:
    #   ConstantReadNode(:User)                    -> "User"
    #   ConstantPathNode(parent: Accounts, :User)  -> "Accounts::User"
    #
    # Returns nil for anything that is not a constant node.
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
