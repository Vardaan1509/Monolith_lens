# frozen_string_literal: true

require_relative "monolith_lens/version"
require_relative "monolith_lens/evidence"
require_relative "monolith_lens/edge"
require_relative "monolith_lens/static/definition"
require_relative "monolith_lens/static/file_analysis"
require_relative "monolith_lens/static/constant_name"
require_relative "monolith_lens/static/constant_visitor"
require_relative "monolith_lens/static/source_analyzer"
require_relative "monolith_lens/static/scan_result"
require_relative "monolith_lens/static/scanner"
require_relative "monolith_lens/packwerk/package"
require_relative "monolith_lens/packwerk/package_set"
require_relative "monolith_lens/analysis/classified_edge"
require_relative "monolith_lens/analysis/edge_classifier"
require_relative "monolith_lens/analysis/package_graph"
require_relative "monolith_lens/analysis/package_analysis"
require_relative "monolith_lens/runtime/trace_ingester"

module MonolithLens
  class Error < StandardError; end
end
