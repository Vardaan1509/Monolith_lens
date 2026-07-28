# frozen_string_literal: true

module MonolithLens
  # A directed dependency: source depends on target, backed by one or more
  # Evidence entries (static analysis now, runtime evidence added later).
  Edge = Data.define(:source, :target, :dependency_type, :evidence)
end
