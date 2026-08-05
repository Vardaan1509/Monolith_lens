# frozen_string_literal: true

require "json"
require "fileutils"
require "pathname"

module MonolithLens
  module Runtime
    # Opt-in runtime tracer. Subscribes to ActiveSupport::Notifications during a
    # test or development run and appends observed dependencies to a JSONL trace
    # file (one JSON object per line).
    #
    # Enabled explicitly, never in production. Requires the host to have
    # ActiveSupport loaded (i.e. a Rails app); it is not loaded by the gem's
    # static-analysis code path.
    class Tracer
      def self.start(output_path:, app_root:)
        new(output_path: output_path, app_root: app_root).start
      end

      def initialize(output_path:, app_root:)
        @output_path = output_path
        @app_root = File.expand_path(app_root)
        @file = nil
      end

      def start
        FileUtils.mkdir_p(File.dirname(@output_path))
        @file = File.open(@output_path, "w")
        subscribe_job_enqueue
        at_exit { @file&.close }
        self
      end

      private

      def subscribe_job_enqueue
        ActiveSupport::Notifications.subscribe("enqueue.active_job") do |event|
          frame = app_frame
          next unless frame

          write_event(
            type: "job_enqueue",
            source_file: relative(frame.path),
            source_line: frame.lineno,
            target: event.payload[:job].class.name
          )
        end
      end

      # The nearest application frame in the call stack (excluding test files):
      # who triggered the observed behaviour.
      def app_frame
        caller_locations.find do |loc|
          loc.path.start_with?(@app_root) && !loc.path.include?("/spec/")
        end
      end

      def relative(path)
        Pathname.new(path).relative_path_from(Pathname.new(@app_root)).to_s
      end

      def write_event(event)
        @file.puts(JSON.generate(event))
        @file.flush
      end
    end
  end
end
