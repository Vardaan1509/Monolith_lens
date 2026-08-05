# frozen_string_literal: true

require "yaml"
require "pathname"

module MonolithLens
  module Packwerk
    # Reads every package.yml under an app root into Package objects, and
    # answers ownership ("which package owns this file?") and dependency
    # ("does package A declare package B?") questions.
    class PackageSet
      def self.load(app_root)
        new(app_root).tap(&:load)
      end

      def initialize(app_root)
        @app_root = Pathname.new(File.expand_path(app_root))
        @packages = []
      end

      attr_reader :packages

      def load
        Dir.glob(@app_root.join("**", "package.yml")).each do |yml|
          @packages << build_package(yml)
        end
        # Most specific (longest name) first, so package_for finds the nearest.
        @packages.sort_by! { |pkg| -pkg.name.length }
        self
      end

      # The package owning a file, given a path relative to the app root.
      def package_for(relative_path)
        @packages.find { |pkg| owns?(pkg, relative_path) }
      end

      def declares?(source, target)
        return true if source == target

        source.dependencies.include?(target.name)
      end

      private

      def build_package(yml_path)
        data = YAML.safe_load_file(yml_path) || {}
        Package.new(
          name: relative_dir(yml_path),
          dependencies: Array(data["dependencies"]),
          enforce_dependencies: data.fetch("enforce_dependencies", false)
        )
      end

      def relative_dir(yml_path)
        Pathname.new(File.dirname(yml_path)).relative_path_from(@app_root).to_s
      end

      def owns?(package, relative_path)
        return true if package.name == "."

        relative_path == package.name || relative_path.start_with?("#{package.name}/")
      end
    end
  end
end
