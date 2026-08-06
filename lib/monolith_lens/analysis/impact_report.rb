# frozen_string_literal: true

module MonolithLens
  module Analysis
    # The blast radius of a change:
    # - changed: constants defined in the changed files
    # - directly_affected: constants that reference a changed constant
    # - transitively_affected: constants reachable further up the dependents
    # - recommended_tests: [{ spec:, covers: }] specs worth running
    ImpactReport = Data.define(
      :changed, :directly_affected, :transitively_affected, :recommended_tests
    )
  end
end
