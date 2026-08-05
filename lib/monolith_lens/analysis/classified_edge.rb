# frozen_string_literal: true

module MonolithLens
  module Analysis
    # A dependency edge with its packages resolved and a classification:
    # :internal, :declared, :boundary_violation, :unchecked, or :external.
    ClassifiedEdge = Data.define(:edge, :source_package, :target_package, :classification)
  end
end
