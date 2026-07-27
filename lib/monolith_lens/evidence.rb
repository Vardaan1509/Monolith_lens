# frozen_string_literal: true

module MonolithLens
  # A single piece of evidence explaining why a dependency edge exists.
  #
  # Every dependency MonolithLens reports must be backed by evidence: which
  # kind of analysis found it (static source reading vs. observed at runtime),
  # the file and line it came from, and the specific rule that matched.
  #
  # This is an immutable value object: once created it cannot be changed, and
  # two Evidence objects with the same fields are considered equal.
  Evidence = Data.define(:kind, :source_file, :line, :rule)
end
