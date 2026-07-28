# frozen_string_literal: true

require "pathname"

module MonolithLens
  module Static
    # Scans a path (a directory tree, or a single .rb file), runs the static
    # SourceAnalyzer on every Ruby file found, and aggregates the edges.
    #
    # It only ever reads files; it never executes the analysed code.
    class Scanner
      def self.scan(path)
        new(path).scan
      end

      def initialize(path)
        @path = path
      end

      def scan
        files = ruby_files
        edges = files.flat_map { |file| analyze_file(file) }
        ScanResult.new(files_scanned: files.length, edges: edges)
      end

      private

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

      # Report file paths relative to what was scanned, so evidence reads
      # "billing/invoice.rb" rather than a long absolute path.
      def relative_path(file)
        base = File.directory?(@path) ? @path : File.dirname(@path)
        Pathname.new(File.expand_path(file))
                .relative_path_from(Pathname.new(File.expand_path(base)))
                .to_s
      end
    end
  end
end
