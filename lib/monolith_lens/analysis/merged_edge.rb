# frozen_string_literal: true

module MonolithLens
  module Analysis
    # A dependency after merging static and runtime evidence.
    #
    # classification is one of:
    # - :static_and_runtime  seen in source code AND observed at runtime
    # - :static_only         seen in source code, not observed at runtime
    # - :runtime_only         observed at runtime, invisible to static analysis
    #
    # confidence is a 0..1 score (see EvidenceMerger for the formula).
    MergedEdge = Data.define(:source, :target, :classification, :evidence, :confidence)
  end
end
