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

## Phase 2 — CLI Layer (Thor) ⬜
`monolith-lens scan PATH` — walk a directory, run the analyzer on every `.rb`
file, print results as JSON. First point where the tool is actually runnable
end-to-end from a terminal.
**Suggested review checkpoint: after this phase.**

## Phase 3 — Demo Rails App (4 domains) ⬜
Accounts, Billing, Notifications, Reporting. Rails 8.1.3 + SQLite. Deliberately
contains: one valid cross-package dependency, one static boundary violation,
one runtime-only hidden dependency, one circular dependency. Exists to prove
the analyzer works against something real — not the main deliverable itself.

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
