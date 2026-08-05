## [Unreleased]

### Added
- Gem skeleton with RSpec, RuboCop, and MIT license.
- `Evidence` and `Edge` immutable value objects for representing dependencies
  and the proof behind them.
- Prism-based static analyzer (`ConstantVisitor`, `SourceAnalyzer`) detecting
  class inheritance, mixins (`include`/`prepend`/`extend`), and qualified
  constant references, each tagged with evidence (file, line, rule).
- `Scanner` for walking a directory tree and aggregating edges across files.
- `monolith-lens scan PATH` CLI command (Thor) printing results as JSON.
- `rubocop-rspec` and `rubocop-performance` linting plugins.
- Packwerk integration: reads `package.yml` files (`Packwerk::PackageSet`),
  resolves constants to packages via scan definitions, and classifies each edge
  as internal/declared/boundary_violation/unchecked/external
  (`Analysis::EdgeClassifier`).
- Package-level dependency cycle detection via `TSort` (`Analysis::PackageGraph`).
- `monolith-lens boundaries` CLI command reporting violations and cycles as JSON.

## [0.1.0] - 2026-07-26

- Initial release
