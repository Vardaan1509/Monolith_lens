# frozen_string_literal: true

module MonolithLens
  module Static
    # Result of scanning a path: files analyzed, edges found, and the
    # constants defined across all files (used to resolve targets to packages).
    ScanResult = Data.define(:files_scanned, :edges, :definitions)
  end
end
