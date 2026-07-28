# frozen_string_literal: true

module MonolithLens
  module Static
    # Result of scanning a path: files analyzed and edges found.
    ScanResult = Data.define(:files_scanned, :edges)
  end
end
