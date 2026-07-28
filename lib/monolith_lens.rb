# frozen_string_literal: true

require_relative "monolith_lens/version"
require_relative "monolith_lens/evidence"
require_relative "monolith_lens/edge"
require_relative "monolith_lens/static/constant_name"
require_relative "monolith_lens/static/constant_visitor"
require_relative "monolith_lens/static/source_analyzer"
require_relative "monolith_lens/static/scan_result"
require_relative "monolith_lens/static/scanner"

module MonolithLens
  class Error < StandardError; end
end
