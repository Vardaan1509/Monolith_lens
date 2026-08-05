# MonolithLens — Phased Build Plan

Goal: an open-source, technically deep Ruby/Rails developer-tooling project
demonstrating engineering judgement for a Shopify SWE internship application.
Built in small, tested, explained vertical slices — no phase is "done" until it
has passing tests, clean RuboCop, and the author (Vardaan) can explain it.

Working style: Kiro implements each slice, explains the Ruby/Rails concepts
involved (this is a from-zero Ruby learning project), then the author reviews,
asks questions, and approves before moving on. Commits happen per-slice.

## Status legend
✅ Done · 🟡 In progress · ⬜ Not started

## Phase 0 — Environment Setup ✅
WSL2 + Ubuntu 26.04, Ruby 3.4.10 (via rbenv), Bundler 4.0.17, Docker Desktop,
Git identity, public GitHub repo (MIT license): github.com/Vardaan1509/Monolith_lens.
Project lives at `~/projects/monolith_lens` inside WSL2 (NOT the Windows C:
drive — that mount doesn't support the Unix file permissions Git/Ruby need).

## Phase 1 — Gem Skeleton + Static Analysis Core 🟡
- ✅ `bundle gem` skeleton (RSpec, RuboCop, MIT, changelog)
- ✅ `Evidence` value object (Data.define) — how we know a dependency exists
- ✅ `Edge` value object (Data.define) — what depends on what
- ✅ Prism-based `ConstantVisitor` + `SourceAnalyzer`
- ✅ Detects: class inheritance (`class Foo < Bar`)
- ✅ Detects: mixins (`include`/`prepend`/`extend`)
- ✅ Detects: qualified constant references (call-receiver vs. value, tagged by
  strength; bare constants deferred until a whole-repo symbol table exists)
- ✅ Extracted `ConstantName` (pure name-reconstruction module)

Phase 1 static-analysis core is COMPLETE.

## Phase 2 — CLI Layer (Thor) ✅
`monolith-lens scan PATH` — walks a directory, runs the analyzer on every `.rb`
file, prints results as JSON (to stdout) plus a summary (to stderr).
- ✅ `MonolithLens::Static::Scanner` (core: walk dir, aggregate edges)
- ✅ `MonolithLens::Static::ScanResult` (files_scanned + edges)
- ✅ `MonolithLens::CLI` (Thor) + `exe/monolith-lens` executable
- ✅ Verified by dogfooding: scanning its own `lib/` produced correct edges.
Run with: `bundle exec exe/monolith-lens scan <path>`

**REVIEW CHECKPOINT: this is the planned stop-and-review point.**

## Phase 3 — Demo Rails App (4 domains) 🟡
Accounts, Billing, Notifications, Reporting. Rails 8.1.3 + SQLite. Lives in
`demo_app/` (a fixture we analyze, excluded from the gem's RuboCop + packaging).

Slice 1 (bootstrap) ✅
- Lean Rails app generated (no frontend/deploy cruft), boots on SQLite.
- rspec-rails + packwerk installed and initialized.
- Four packages under `packs/*` with `package.yml` boundary declarations;
  autoload configured so `packs/billing/app/models/billing/invoice.rb` maps to
  `Billing::Invoice`. `packwerk validate` passes.

Slice 2 (fill in domains) ✅ — models, service objects, and a job across the
four packs, with all four intentional scenarios wired and 10 passing specs:
- Valid declared deps: billing/reporting/notifications -> accounts, reporting -> billing.
- Boundary violation: Notifications::InvoiceAlert references Billing::Invoice
  (undeclared). Packwerk reports 1 of its 2 offenses here.
- Cycle: Billing::InvoiceProcessor references Reporting::RevenueSummary
  (undeclared) while reporting declares billing. Packwerk's other offense.
- Hidden runtime dep: Billing::InvoiceProcessor enqueues Notifications::ReceiptJob
  via a string ("Notifications::ReceiptJob".constantize) - invisible to Packwerk
  and static analysis, only observable at runtime.
Slice 3 (verify) ✅ — MonolithLens scan of demo_app/packs produces 9 edges:
all valid cross-domain deps, the boundary-violating reference, and BOTH halves
of the billing<->reporting cycle. It does NOT produce a billing->notifications
edge (the string-based job dependency is invisible to static analysis) - the
core thesis, demonstrated. Locked in as an integration spec
(spec/integration/demo_app_scan_spec.rb). Main gem: 31 examples, RuboCop clean.

Phase 3 (demo Rails app) is COMPLETE.

Design note: Packwerk `validate` REJECTS declared cycles (the declared graph
must be acyclic). So the intentional cycle is created via an *undeclared* code
reference (billing -> reporting) plus the declared reporting -> billing. Packwerk
reports it only as an undeclared reference; MonolithLens surfaces it as a cycle.

## Phase 4 — Packwerk Integration ⬜
Read `package.yml` files directly (YAML), shell out to `packwerk check` safely
(array args, no string interpolation), classify edges as declared-dependency
or boundary-violation.

## Phase 5 — Runtime Tracing ⬜
ActiveSupport::Notifications-based instrumentation adapter in the demo app
(SQL, ActiveJob enqueue/perform, one custom service-call event).
`monolith-lens trace -- bundle exec rspec` records a runtime trace.

## Phase 6 — Evidence Merging + Confidence Scoring ⬜
Joint design (ADR) for the confidence formula, then implementation. Classifies
every edge into: static+runtime confirmed, static-only, runtime-only, declared,
observed-undeclared, boundary violation, stale-declared, unknown — each with a
plain-English explanation.

## Phase 7 — Redis Caching Layer ⬜
Content-addressed caching (file SHA256 keys), cache stats, `cache stats`/
`cache clear` commands, fail-open behaviour verified by killing Redis mid-scan.

## Phase 8 — Git-Aware Impact Analysis + Test Recommendations ⬜
Safe `git diff` subprocess calls, reverse-graph traversal (direct vs.
transitive impact + dependency path), RSpec test recommendations with reason
and confidence, honest phrasing (never "this test is guaranteed unnecessary").

## Phase 9 — Reports (JSON, Markdown, HTML) ⬜
Documented JSON schema, PR-ready Markdown, and (stretch) an interactive
Cytoscape.js HTML report with an evidence click-through panel.

## Phase 10 — Polish for Impressiveness ⬜
README (problem, differentiation vs. Packwerk/Graphwerk/Kaskd/AppMap/
Crystalball), recorded demo, real measured benchmarks (never fabricated),
GitHub Actions workflow, SECURITY.md/LIMITATIONS.md/CONTRIBUTING.md, ADRs.

## Approved scope decisions (locked in during planning)
- Single gem (core + CLI as modules, not two separate gemspecs).
- 4 demo-app domains (Accounts, Billing, Notifications, Reporting), not 6.
- SQLite for the demo app, not MySQL.
- MIT license, public repo from day one.
- ~2 hours/day pace — plan favours depth over breadth on the Tier 1 list.
- Two "impress Shopify" upgrades approved: (1) a single visible "Blast Radius
  Score" in the impact report, (2) a GitHub Action that posts impact analysis
  as an actual PR comment, not just a job summary artifact. Both stay in
  Phase 9/10.

## Where we are right now
Finishing Phase 1 (constant references), then Phase 2 (CLI). The end of
Phase 2 is the planned first "stop and review everything" checkpoint — it's
the earliest point where the tool can be run directly from a terminal rather
than only through tests.
