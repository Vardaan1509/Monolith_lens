# frozen_string_literal: true

module MonolithLens
  module Static
    # A constant (class or module) defined in the source, and where.
    # Used to resolve a referenced constant back to the file (and package)
    # that defines it.
    Definition = Data.define(:constant, :source_file, :line)
  end
end
