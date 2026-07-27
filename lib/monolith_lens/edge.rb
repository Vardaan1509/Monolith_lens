# frozen_string_literal: true

module MonolithLens
  # A directed dependency edge: `source` depends on `target`.
  #
  # Fields:
  # - source: the fully-qualified constant that HAS the dependency,
  #   e.g. "Billing::InvoiceProcessor"
  # - target: the fully-qualified constant it depends ON,
  #   e.g. "Accounts::User"
  # - dependency_type: a Symbol naming the kind of dependency, e.g.
  #   :constant_reference, :inheritance, :include, :prepend, :extend
  # - evidence: an Array of Evidence objects supporting this edge. Usually one
  #   when first extracted by the static analyzer; the later merge step may add
  #   more (e.g. runtime evidence for the same source -> target).
  #
  # Immutable value object, compared by value (see Evidence for the rationale
  # behind Data.define).
  Edge = Data.define(:source, :target, :dependency_type, :evidence)
end
