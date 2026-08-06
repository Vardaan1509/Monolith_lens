# frozen_string_literal: true

require "open3"

module MonolithLens
  module Git
    # Lists the Ruby files changed between two git refs. Uses array-form
    # arguments (never a shell string), so ref names can't inject commands.
    class DiffAnalyzer
      def self.changed_ruby_files(repo:, base:, head:)
        new(repo: repo).changed_ruby_files(base: base, head: head)
      end

      def initialize(repo:)
        @repo = repo
      end

      def changed_ruby_files(base:, head:)
        stdout, status = Open3.capture2(
          "git", "-C", @repo, "diff", "--name-only", "#{base}...#{head}"
        )
        return [] unless status.success?

        stdout.lines(chomp: true).select { |file| file.end_with?(".rb") }
      end
    end
  end
end
