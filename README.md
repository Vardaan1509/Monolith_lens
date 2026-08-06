# MonolithLens

**What could this code change affect, and what evidence supports that conclusion?**

MonolithLens is a static + runtime dependency analyzer for modular Rails
monoliths. It reads your source code, reads your [Packwerk](https://github.com/Shopify/packwerk)
package boundaries, and (optionally) observes what your test suite actually
does at runtime, then combines all three to answer a question none of them
can answer alone: given a Git diff, what breaks, how confident should you be,
and which tests are worth running.

It ships with a small, deliberately modular demo Rails application used to
prove every claim below against real, runnable code, not a hand-picked example.

## The problem

Large Rails codebases (Shopify's own monolith is the canonical example) get
split into packages to keep them maintainable. Two things go wrong over time:

1. Code quietly crosses boundaries it shouldn't.
2. Nobody can confidently answer "if I change this, what else might break, and
   what should I test?" The real dependency graph is scattered across static
   code, runtime behaviour, and Git history, and no single tool looks at all
   three together.

## Why static analysis alone is not enough

Packwerk, Shopify's own open-source boundary-enforcement tool, says this
about itself, in its own README:

> "Method calls and objects passed around the application are completely
> ignored. Packwerk only cares about static constant references... we accept
> a small number of false negatives."

That is a real, admitted limitation, and it is the reason MonolithLens exists.
The demo app in this repo contains a dependency that is enqueued through a
string (`"Notifications::ReceiptJob".constantize.perform_later(...)`) rather
than a plain constant reference. Static analysis, Packwerk's and ours,
cannot see it. Running the test suite with tracing enabled does.

## How MonolithLens differs from existing tools

MonolithLens does not replace or claim to out-perform the tools it builds on:

| Tool | What it does | How MonolithLens relates |
|---|---|---|
| **Packwerk** | Enforces declared package boundaries via static analysis | We read its `package.yml` files directly and reuse its notion of a package |
| **Graphwerk** | Visualizes Packwerk's declared package graph | We build a similar graph, but from *actual* edges (static + runtime), and use it to detect cycles Packwerk cannot name |
| **AppMap** | Captures runtime execution traces | We use a narrower, purpose-built runtime tracer (job enqueues) specifically to corroborate or contradict static evidence, not for general observability |
| **Crystalball** | Runtime-based regression test selection | Our test recommendation is simpler (graph + naming convention) but is derived from the same merged static+runtime graph as everything else, not a separate subsystem |

The differentiator is not any one piece. It's combining declared
architecture, static analysis, and runtime observation into one evidence
model, and using that model for Git-diff-driven change-impact analysis.

## Architecture

```
Ruby source ──▶ Prism AST ──▶ ConstantVisitor ──▶ static Edges (+ Evidence)
                                                         │
Rails test run ──▶ ActiveSupport::Notifications ──▶ Tracer ──▶ runtime Edges
                                                         │
                                                         ▼
                                    EvidenceMerger ──▶ MergedEdges
                                    (classification + confidence)
                                                         │
package.yml files ──▶ PackageSet ──▶ EdgeClassifier ──▶ violations + cycles
                                                         │
git diff ──▶ DiffAnalyzer ──▶ ImpactAnalyzer (reverse graph) ──▶ blast radius
                                                         │
                                                         ▼
                                              CLI (JSON output)
```

Core analysis code has no dependency on the CLI; the CLI is a thin Thor
wrapper that formats output.

## How static analysis works

`MonolithLens::Static::ConstantVisitor` walks a [Prism](https://github.com/ruby/prism)
AST and extracts three kinds of high-confidence dependency, each with evidence
(file, line, the rule that found it):

- Class inheritance (`class Foo < Bar`)
- Mixins (`include` / `prepend` / `extend`)
- Qualified constant references (`Accounts::User.find`), tagged by how they
  were used (call receiver vs. plain value) so later confidence scoring can
  weigh them differently

It never executes the analyzed code, and it never claims to build a complete
Ruby call graph. Ruby is too dynamic for that. Bare, unqualified constants
(`String`, `MAX_SIZE`) are deliberately not treated as dependencies yet:
telling application code apart from a language built-in needs a whole-repo
symbol table, which is a documented, honest limitation rather than a guess.

## How runtime tracing works

`MonolithLens::Runtime::Tracer` is opt-in and subscribes to Rails' own
`ActiveSupport::Notifications` (no monkey-patching, no `TracePoint`) during a
test run. When a background job is enqueued, it records the target job and
uses the call stack to attribute which application code triggered it, writing
one JSON object per line to a trace file. It is only ever enabled explicitly
via an environment variable, never in production.

## How evidence is merged

`MonolithLens::Analysis::EvidenceMerger` groups static and runtime edges by
`(source, target)` and classifies each into:

- `static_and_runtime`: confirmed by both sources (confidence 1.0)
- `runtime_only`: real, but invisible to static analysis (confidence 0.7)
- `static_only`: seen in source, not observed at runtime; scored by how
  strong the static signal was (inheritance/mixin: 0.85, call receiver: 0.7,
  plain value: 0.5)

Neither absence is treated as proof of anything. A runtime-only edge is not
assumed incorrect (it may be real, unexercised-by-tests behaviour); a
static-only edge is not assumed stale (it may simply not have been exercised
during the trace). The formula is deliberately simple and fully documented
here rather than tuned to a specific dataset.

## How Packwerk boundaries and cycles are calculated

`MonolithLens::Packwerk::PackageSet` reads every `package.yml` directly
(plain YAML, not Packwerk's internal Ruby API, which is not a stable public
interface). `MonolithLens::Analysis::EdgeClassifier` resolves each edge's
target to its owning package and classifies it as internal, declared,
boundary-violating, or external.

Packwerk checks one reference at a time and can only ever report "undeclared
reference." Because MonolithLens builds the *whole* package graph, it can
additionally answer a question Packwerk structurally cannot: whether any
packages depend on each other in a loop. This is done with Ruby's standard
library `TSort` (strongly connected components): no custom graph algorithm,
no added dependency.

## How change impact is calculated

`MonolithLens::Git::DiffAnalyzer` lists the Ruby files changed between two
Git refs using array-form subprocess arguments (never an interpolated shell
string, to avoid command injection). `MonolithLens::Analysis::ImpactAnalyzer`
maps those files to the constants they define, then walks the *reverse*
dependency graph outward: direct dependents, then transitive dependents,
breadth-first, until nothing new is found.

It also produces a single **blast radius score**: a weighted count of the
affected code, where direct dependents count 3× and transitive dependents 1×,
because a direct dependent is more likely to actually break. It's a quick
at-a-glance sense of "how risky is this change" that sits at the top of the
impact report (e.g. changing `Billing::Invoice` in the demo app scores 7:
two direct dependents × 3, plus one transitive × 1).

## How test recommendations are generated

For every affected constant, MonolithLens looks up its source file and
recommends any spec file matching Ruby's naming convention
(`invoice.rb` → `invoice_spec.rb`). This is intentionally simple rather than
elaborate reason-ranking, and it never claims that an unselected test is
guaranteed unnecessary, only that these specific tests cover code in the
blast radius.

## The demo Rails application

`demo_app/` is a small, four-package modular Rails app (Accounts, Billing,
Notifications, Reporting) that exists purely to prove MonolithLens works
against something real. It deliberately contains:

- A valid, declared cross-package dependency (`Billing → Accounts`)
- A static boundary violation (`Notifications::InvoiceAlert` reaches into
  `Billing::Invoice` without `packs/notifications` declaring `packs/billing`)
- A dependency cycle (`Billing::InvoiceProcessor` references
  `Reporting::RevenueSummary` without declaring it, while Reporting declares
  Billing). Packwerk cannot declare a cycle directly (`packwerk validate`
  rejects it), so real cycles necessarily appear as undeclared references;
  MonolithLens names the loop, Packwerk cannot
- A runtime-only hidden dependency (`Billing::InvoiceProcessor` enqueues
  `Notifications::ReceiptJob` via `"Notifications::ReceiptJob".constantize`,
  invisible to static analysis)

## Running it

Requires Ruby 3.4+ (developed against 3.4.10) and Bundler.

```bash
bundle install

# Static scan of any Ruby codebase
bundle exec exe/monolith-lens scan demo_app/packs

# Classify edges against Packwerk packages; report violations and cycles
bundle exec exe/monolith-lens boundaries demo_app/packs --app-root demo_app

# Run a test suite with runtime tracing enabled
bundle exec exe/monolith-lens trace --output tmp/trace.jsonl -- bundle exec rspec

# Git-diff-driven blast radius and test recommendations
bundle exec exe/monolith-lens impact --repo demo_app --base main --head HEAD
```

Run the gem's own test suite:

```bash
bundle exec rspec       # 59 examples
bundle exec rubocop     # 0 offenses
```

Run the demo app's own test suite (from `demo_app/`):

```bash
bundle exec rspec       # 10 examples
```

## Verified results (this repository, run against the bundled demo app)

Running `monolith-lens boundaries` against `demo_app/packs` produces exactly:

- **9** dependency edges analyzed
- **2** boundary violations, matching `packwerk check` exactly, each with
  file and line evidence
- **1** dependency cycle (`packs/billing` ↔ `packs/reporting`) that Packwerk
  cannot express as a single finding
- **0** false negatives on the runtime-only dependency when tracing is
  enabled: the hidden `Billing → Notifications::ReceiptJob` edge is recovered
  and classified `runtime_only`, and confirmed absent from the static scan

These numbers are reproduced by the commands above and locked in by the
integration specs under `spec/integration/`. Nothing here is estimated.

## Validated against Shopify's own Packwerk fixtures

To sanity-check the static scanner against real-world Ruby rather than only
the bundled demo app, I ran `monolith-lens scan` against the `skeleton` and
`minimal` fixtures from
[Shopify/packwerk](https://github.com/Shopify/packwerk)'s own test suite
(MIT-licensed; used here for local testing only, not vendored into this
repo). Those fixtures exercise real Sorbet `# typed:` annotations, classes
reopened across multiple files, deeply nested namespaces
(`Sales::Order::Error`), and Shopify's own `components/<name>/app/{models,
internal,public}` package layout, and the scanner parsed all of it cleanly
with zero crashes.

The fixtures themselves define constants without referencing each other (by
design: Packwerk's own tests inject references at the test-code level, not
in the fixtures), so the correct scan result is genuinely 0 edges. To confirm
that's a fact about the fixtures and not a bug in MonolithLens, I reproduced
Shopify's exact package layout with one added cross-package reference
(`Sales::Order` calling `Timeline::Event`) and confirmed the scanner found it
and attributed it correctly:

```
Scanned 2 file(s); found 1 edge(s).
Sales::Order -> Timeline::Event (constant_reference, line 5)
```

## Security

- The static analyzer never executes analyzed code.
- Git and Packwerk are invoked with array-form subprocess arguments, never
  interpolated shell strings.
- Runtime tracing is opt-in, environment-gated, and intended for test/dev use
  only.
- No environment variables, SQL literal values, or secrets are recorded in
  traces or reports.

## Future work

Deliberately out of scope for this stage, in order of what I'd build next:

- **Redis-backed incremental caching**: content-addressed keys per file
  hash (`monolith_lens:v1:ast:{repo}:{sha256}`), so a warm re-scan skips
  unchanged files. Designed with a fail-open requirement (a Redis outage
  degrades performance, never correctness) and cache versioning to avoid
  deserializing stale schemas. Deferred because nothing else in this stage
  is slow enough yet to make the cache-hit numbers meaningful.
- **Interactive HTML report** (Cytoscape.js graph with an evidence panel):
  JSON output already contains everything needed to render one.
- **GitHub Actions integration**: running `monolith-lens impact` against a
  pull request diff and posting the result as a check or PR comment.
- **Whole-repository symbol table**: to safely start reasoning about bare,
  unqualified constant references.
- **Additional runtime signals**: SQL activity, callback execution, and a
  custom service-call instrumentation event, using the same
  `ActiveSupport::Notifications` mechanism already in place.
- **Additional test-framework adapters**: the recommendation logic assumes
  RSpec-style spec naming; the interface is narrow enough to add Minitest
  support without changing callers.

## License

MIT. See [LICENSE](LICENSE).
