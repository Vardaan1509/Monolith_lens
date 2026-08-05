# frozen_string_literal: true

module MonolithLens
  module Static
    # Result of analyzing one file: the dependency edges found and the
    # constants (classes/modules) defined in it.
    FileAnalysis = Data.define(:edges, :definitions)
  end
end
