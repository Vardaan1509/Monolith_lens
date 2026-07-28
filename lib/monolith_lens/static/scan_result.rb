# frozen_string_literal: true

module MonolithLens
  module Static
    # The result of scanning a path: how many Ruby files were analysed and the
    # dependency edges found across all of them.
    #
    # Will grow more fields later (e.g. cache hits, parse failures); keeping it
    # as a value object means callers get a stable, self-describing return type.
    ScanResult = Data.define(:files_scanned, :edges)
  end
end
