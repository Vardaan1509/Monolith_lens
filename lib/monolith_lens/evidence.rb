# frozen_string_literal: true

module MonolithLens
  # Proof that a dependency edge exists: what kind of analysis found it,
  # and where (file, line, rule).
  Evidence = Data.define(:kind, :source_file, :line, :rule)
end
