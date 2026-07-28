# frozen_string_literal: true

require_relative "lib/monolith_lens/version"

Gem::Specification.new do |spec|
  spec.name = "monolith_lens"
  spec.version = MonolithLens::VERSION
  spec.authors = ["Vardaan Mehandiratta"]
  spec.email = ["vardaanmehandiratta926@gmail.com"]

  spec.summary = "Evidence-based change-impact analysis for modular Rails monoliths."
  spec.description = "MonolithLens combines static source analysis, Packwerk " \
                     "package boundaries, and observed runtime behaviour to answer " \
                     "one question: what could this code change affect, and what " \
                     "evidence supports that conclusion? It reports direct and " \
                     "transitive impact, surfaces hidden runtime dependencies, and " \
                     "recommends the tests worth running."
  spec.homepage = "https://github.com/Vardaan1509/Monolith_lens"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Uncomment the line below to require MFA for gem pushes.
  # This helps protect your gem from supply chain attacks by ensuring
  # no one can publish a new version without multi-factor authentication.
  # See: https://guides.rubygems.org/mfa-requirement-opt-in/
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Prism is Ruby's official parser. It turns Ruby source code into the AST
  # (abstract syntax tree) that our static analyzer walks. Pinned at patch level
  # (~> 1.9.0 means ">= 1.9.0, < 1.10.0") because the visitor depends on specific
  # AST node shapes, which can shift between minor versions.
  spec.add_dependency "prism", "~> 1.9.0"

  # Thor powers the command-line interface (`monolith-lens scan ...`). It's the
  # same CLI toolkit Rails' own generators are built on.
  spec.add_dependency "thor", "~> 1.5"

  # For more information and examples about making a new gem, check out our
  # guide at: https://guides.rubygems.org/make-your-own-gem/
end
