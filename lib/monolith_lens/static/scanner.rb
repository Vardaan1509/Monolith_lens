# frozen_string_literal: true

require "pathname"

module MonolithLens
  module Static
    # Scans a path (a directory tree, or a single .rb file), runs the static
    # SourceAnalyzer on every Ruby file found, and aggregates the results.
    #
    # `base:` controls what evidence paths are reported relative to. It
    # defaults to the scanned path, but can be set to a wider root (e.g. an app
    # root) so paths line up with Packwerk package names.
    #
    # It only ever reads files; it never executes the analysed code.
    class Scanner
      def self.scan(path, base: nil)
        new(path, base: base).scan
      end

      def initialize(path, base: nil)
        @path = path
        @base = base || default_base
      end

      def scan
        files = ruby_files
        analyses = files.map { |file| analyze_file(file) }

        ScanResult.new(
          files_scanned: files.length,
          edges: analyses.flat_map(&:edges),
          definitions: analyses.flat_map(&:definitions)
        )
      end

      private

      def default_base
        File.directory?(@path) ? @path : File.dirname(@path)
      end

      def ruby_files
        if File.directory?(@path)
          Dir.glob(File.join(@path, "**", "*.rb"))
        elsif ruby_file?(@path)
          [@path]
        else
          []
        end
      end

      def ruby_file?(path)
        File.file?(path) && File.extname(path) == ".rb"
      end

      def analyze_file(file)
        source = File.read(file)
        SourceAnalyzer.analyze(source, source_file: relative_path(file))
      end

      def relative_path(file)
        Pathname.new(File.expand_path(file))
                .relative_path_from(Pathname.new(File.expand_path(@base)))
                .to_s
      end
    end
  end
end
