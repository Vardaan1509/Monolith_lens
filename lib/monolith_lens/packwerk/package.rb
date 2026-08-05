# frozen_string_literal: true

module MonolithLens
  module Packwerk
    # A single Packwerk package. `name` is its path relative to the app root
    # (Packwerk's own naming), or "." for the root package. `dependencies` are
    # the package names it is allowed to depend on. `enforce_dependencies`
    # says whether its cross-package references are checked at all.
    Package = Data.define(:name, :dependencies, :enforce_dependencies)
  end
end
