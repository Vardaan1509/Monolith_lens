# Learning Notes

A running log of the Ruby/Rails concepts introduced while building MonolithLens,
written for someone coming from C#, TypeScript/JavaScript, and .NET.

Each entry aims to cover: **what** it is, **why** we need it here, and a
**comparison** to something already familiar.

---

## Phase 0 — Environment

### Why WSL2 (Linux) instead of native Windows Ruby
Many Ruby gems include C code that is **compiled on your machine** during
`bundle install` (e.g. `rbs`, and later the `redis` client). That needs a Unix
build toolchain (`gcc`, `make`, dev headers). On Linux this is trivial; on native
Windows it is a frequent source of cryptic failures. GitHub Actions CI also runs
Ubuntu, so developing on Linux means "works on my machine" == "works in CI".

### Why the project lives in the Linux filesystem, NOT on the C: drive
We first tried scaffolding on `C:` (accessed from Linux via `/mnt/c/...`). It
**failed**: `chmod ... Operation not permitted`. Git and Ruby tooling set Unix
file permissions, which the Windows drive mount does not allow from Linux. This
is a functional incompatibility, not just slowness. So the project lives at
`~/projects/monolith_lens` (native Linux). Kiro still edits it from the Windows
side through the `\\wsl.localhost\Ubuntu\...` path.

### rbenv + ruby-build
- **rbenv**: lets multiple Ruby versions coexist and switches between them per
  project. Closest analogy: `nvm` for Node.
- **ruby-build**: an rbenv plugin that downloads + compiles a specific Ruby
  version from source. (Plugin architecture, like ESLint/webpack plugins.)
- `rbenv global 3.4.10` sets the default version machine-wide.

### Bundler
Reads a `Gemfile` (dependency list) + `Gemfile.lock` (exact resolved versions)
and installs precisely those, so every environment is identical.
- `Gemfile`      ~= `package.json` dependencies
- `Gemfile.lock` ~= `package-lock.json`
- `bundle install`, `bundle exec <cmd>` (run a command with the locked gems)

---

## Phase 1 — Gem structure

### What a "gem" is
Ruby's unit of shareable code = an npm package / NuGet package. `bundle gem NAME`
scaffolds a conventional gem skeleton.

### File layout and what each piece maps to
| File | Role | Familiar analog |
|------|------|-----------------|
| `NAME.gemspec` | Gem manifest: name, version, license, **runtime** deps | `.csproj` metadata + `package.json` |
| `Gemfile` | **Development** deps (test/lint tools). `gemspec` line pulls in runtime deps too | `package.json` devDependencies |
| `lib/NAME.rb` | Entry point; defines the top-level module | `src/index.ts` |
| `lib/NAME/version.rb` | Single source of truth for the version string | — |
| `spec/` | Tests (RSpec) | `__tests__/` or a Tests project |
| `.rspec` | Default test-run flags | jest config |
| `.rubocop.yml` | Linter + formatter config | ESLint + Prettier / .NET analyzers |
| `Rakefile` | Task runner; `rake` runs tests + lint | make / npm scripts / MSBuild |
| `bin/console` | REPL with the gem preloaded | `node` with module required |
| `sig/NAME.rbs` | Optional type signatures (RBS) | `.d.ts` in TypeScript |

### `module` = namespace
```ruby
module MonolithLens
  class Error < StandardError; end
end
```
- `module` is a named container ~ C# `namespace`.
- `::` is the namespace separator: `MonolithLens::Static::ConstantVisitor`
  reads like C# `MonolithLens.Static.ConstantVisitor`.
- `class Error < StandardError` = inheritance; `<` means "inherits from"
  (C#: `class Error : Exception`).

### Runtime deps vs dev deps — the split
- Goes in **.gemspec**: things the gem needs to run for its users (later: `prism`, `redis`, `thor`).
- Goes in **Gemfile**: things only needed to develop it (`rspec`, `rubocop`, `rake`).

### RSpec basics
```ruby
RSpec.describe MonolithLens do
  it "has a version number" do
    expect(MonolithLens::VERSION).not_to be nil
  end
end
```
- `describe` groups tests; `it` is one example; `expect(x).to matcher`.
- Very close to Jest's `describe`/`it`/`expect`.
- `bundle exec rspec` runs the suite. A fresh scaffold ships one intentionally
  failing placeholder test (`expect(false).to eq(true)`) as a reminder.

### `# frozen_string_literal: true`
A magic comment at the top of every file. It makes string literals immutable,
which is faster and prevents a class of bugs. Idiomatic in modern Ruby; RuboCop
enforces it. (No direct C#/TS equivalent — strings are immutable there anyway.)

---

## Ruby language basics (the minimum to read our code)

```ruby
puts "Hello, world!"     # print a line — Ruby's hello world
name = "Vardaan"         # variables: no type declaration (dynamically typed)
def greet(who)           # method definition; `end` closes it (no braces)
  "Hi #{who}"            # last expression is the return value; #{} = interpolation
end
```

- **`end`** closes every block (def/class/module/if) — Ruby's alternative to `{ }`.
- **Everything is an object**; call methods with a dot: `evidence.kind`.
- **`#`** starts a comment. No semicolons; newline ends a statement.
- **Constants** (including class/module names) start with a capital letter.

### Symbols (`:static`)
An immutable, interned name-tag. Same symbol is always the same object, so they
are cheap and ideal as fixed labels / hash keys / flags.
- `:static` (symbol) vs `"static"` (string): use a symbol when the value is a
  fixed identifier in the code, a string when it is data/text.
- Closest analogs: an enum member, or an interned string constant.

### Keyword arguments
```ruby
Evidence.new(kind: :static, source_file: "x.rb", line: 1, rule: "r")
```
Arguments passed **by name** (`key: value`), which makes calls self-documenting.

## Value objects with `Data.define` (Ruby 3.2+)
```ruby
Evidence = Data.define(:kind, :source_file, :line, :rule)
```
- Builds a new class whose instances hold exactly those named fields.
- **Immutable** (no setters), compared **by value** (two with equal fields are
  `==`), auto-generated getters (`.kind`, ...), readable `to_s`.
- This is Ruby's answer to a **C# `record`**.
- Alternatives: `Struct` (older, mutable by default) or a hand-written class.
  We prefer `Data.define` for immutable value objects.

## `require_relative`
```ruby
require_relative "monolith_lens/evidence"
```
Loads another Ruby file relative to the current file (no `.rb` needed). This is
the plain-Ruby way to connect files. (Rails later does this automatically via
"autoloading"; our gem wires it explicitly.)

## RSpec syntax
```ruby
RSpec.describe MonolithLens::Evidence do   # a group of tests about this class
  it "exposes the fields it was created with" do   # one example
    evidence = described_class.new(...)    # described_class = the class in describe
    expect(evidence.kind).to eq(:static)   # assertion: expect(x).to matcher
  end
end
```
Run with `bundle exec rspec`. Very close to Jest's `describe`/`it`/`expect`.

## Cross-platform line endings (LF vs CRLF)
- Linux/Ruby/CI expect **LF** (`\n`); Windows editors often write **CRLF** (`\r\n`).
- RuboCop flags CRLF via `Layout/EndOfLine`.
- Fix: a `.gitattributes` with `* text=auto eol=lf` pins the repo to LF.
- Note for this project: creating a brand-new file from the Windows side writes
  CRLF; we normalize to LF (git handles it on commit via `.gitattributes`).

## Tooling niceties enabled
- `.rubocop.yml` → `AllCops: NewCops: enable` opts into RuboCop's newer checks.
- `Gemspec/RequireMFA`: gemspec declares `rubygems_mfa_required = "true"`
  (supply-chain hygiene: publishing a new version would require MFA).

---

## Edge value object + more RSpec

### `Edge` — a dependency, holding a list of evidence
```ruby
Edge = Data.define(:source, :target, :dependency_type, :evidence)
```
- `source` -> `target` are fully-qualified constant names (Strings).
- `dependency_type` is a Symbol from a known set
  (`:constant_reference`, `:inheritance`, `:include`, `:prepend`, `:extend`).
- `evidence` is an **Array** of `Evidence`. Starting as an array (even when
  extraction produces just one) means the later static+runtime merge step can
  append more evidence for the same edge without a refactor.

### RSpec `let`
```ruby
let(:evidence) { MonolithLens::Evidence.new(...) }
```
- Defines a **lazy, memoized** helper: the block runs the first time `evidence`
  is used in an example, then the value is cached for that example.
- Resets fresh for each `it`. The idiomatic way to share setup without repetition.

### RuboCop: excluding legitimately-long blocks
`Metrics/BlockLength` guards against over-long method/blocks, but some blocks are
declaration-heavy by nature. We exclude:
- `spec/**/*` — RSpec `describe` blocks hold many `it` examples.
- `*.gemspec` — the `Gem::Specification.new do ... end` manifest block.

---

## Static analysis with Prism (the AST + Visitor)

### AST (Abstract Syntax Tree)
`Prism.parse(source)` turns Ruby *text* into a tree of typed **nodes** describing
the code's structure: `ModuleNode`, `ClassNode`, `CallNode`, `ConstantReadNode`,
`ConstantPathNode`, etc. Static analysis = walk this tree and turn interesting
nodes into `Edge`s. We never run the code. (Same idea as a compiler front-end or
a linter like ESLint/RuboCop.)

Useful node fields we use:
- `ClassNode#constant_path` (the name) and `#superclass` (what it inherits from).
- `ConstantReadNode#name` -> Symbol like `:User`.
- `ConstantPathNode#parent` + `#name` -> reconstruct `"Accounts::User"`.
- every node has `#location` with `#start_line` (free evidence line numbers).

Tip: `puts Prism.parse(src).value.inspect` pretty-prints the whole tree — great
for exploring before writing a visitor.

### The Visitor pattern (`Prism::Visitor`)
```ruby
class ConstantVisitor < Prism::Visitor
  def visit_class_node(node)   # called for every `class ... end`
    # ...do something with node...
    super                      # IMPORTANT: descends into the class body
  end
end
Prism.parse(src).value.accept(visitor)   # start the walk
```
- Subclass `Prism::Visitor` and override `visit_<node_type>` for the nodes you
  care about. Everything else is ignored automatically.
- Calling `super` runs the default behaviour = visit the node's children. Forget
  it and you won't descend into nested code.
- Same shape as a Roslyn `CSharpSyntaxWalker` (C#).

### Tracking "where am I?" with a namespace stack
To know that a superclass reference lives inside `Billing::InvoiceProcessor`, the
visitor pushes the name when it enters a module/class and pops when it leaves:
```ruby
def visit_module_node(node)
  @namespace.push(name)   # entering
  super                   # walk children (the inside)
  @namespace.pop          # leaving
end
```
`@namespace.join("::")` is then the current fully-qualified source name.

### New Ruby syntax seen here
- **`@variable`** = an *instance variable* (per-object state). No declaration; it
  just exists once assigned. (C#: a private field.)
- **`attr_reader :edges`** = auto-generates a getter method `edges`. (C#: a
  read-only property.)
- **`super()`** vs **`super`**: `super()` calls the parent method with NO args;
  bare `super` forwards the same args it received. In `initialize` we use
  `super()` because `Prism::Visitor#initialize` takes none.
- **`def self.analyze(...)`** = a *class method* (called on the class itself:
  `SourceAnalyzer.analyze(...)`), vs an instance method. (C#: a `static` method.)
- **`case node; when Prism::ConstantReadNode ... end`** = pattern-matching on the
  object's class. `when X` tests `X === node` (here: "is node an X?").
- **Heredoc `<<~RUBY ... RUBY`** = a multi-line string literal; the `~` strips
  leading indentation so the code stays readable. Used a lot in specs.

### Graceful failure
`Prism.parse` never raises on bad Ruby; it returns a result with `success? =>
false` and an `errors` list (error-tolerant parsing). `SourceAnalyzer` checks
`result.success?` and returns `[]` on failure, so one broken file can't crash a
whole scan.

---

## Detecting mixins (include / prepend / extend)

Key insight: `include Auditable` is NOT special syntax — it's a plain **method
call**. So in the AST it is a `CallNode` (name: `:include`, argument: the
module). We add `visit_call_node` and recognise the three mixin method names.

```ruby
MIXIN_METHODS = %i[include prepend extend].freeze

def visit_call_node(node)
  record_mixins(node) if mixin_call?(node)
  super
end

def mixin_call?(node)
  node.receiver.nil? && MIXIN_METHODS.include?(node.name)
end
```
- `node.receiver.nil?` = a *bare* `include Foo`, not `obj.include?(x)`. Guards
  against mistaking an unrelated method call for a mixin.
- `node.name` (`:include` etc.) is used directly as the `dependency_type`.
- Multiple modules (`include A, B`) -> one edge each. Dynamic args
  (`include some_method`) are ignored (they don't resolve to a constant).

### New Ruby syntax
- **`%i[a b c]`** = array of symbols `[:a, :b, :c]`. (`%w[a b c]` = array of
  strings.)
- **`.freeze`** = make an object immutable. Idiomatic on constants so they can't
  be mutated by accident.
- **`&.`** (safe navigation) = `node.arguments&.arguments` returns `nil` instead
  of raising if `node.arguments` is `nil`. (C#: `?.`)
- **`|| []`** = default value: `x || []` uses `[]` when `x` is `nil`/false.
- **`.select { |x| ... }`** = keep elements where the block is truthy (filter).
- **`.map(&:target)`** = call `.target` on each element. `&:sym` turns a symbol
  into a block — shorthand for `.map { |x| x.target }`.
- **`.to_h { |x| [key, value] }`** = build a Hash from a list.

### New RSpec matcher
- **`contain_exactly(a, b)`** = the array has exactly these elements, in any
  order. (Order-independent, unlike `eq([a, b])`.)

---

## Constant references + a key design decision (precision vs. recall)

### The design decision
When code says `Accounts::User.find(1)`, that's a dependency. But constants
appear everywhere (`String`, `MAX_SIZE`, local constants) and most are noise.

- **Precision** = of what we report, how much is truly meaningful.
- **Recall** = of the real dependencies, how many did we catch.
Static analysis of a dynamic language can't max both at once.

Decision (matches the project's "record evidence, don't pretend certainty"
philosophy): **capture broadly, tag by strength, filter later** at the
confidence-scoring step — rather than hard-dropping at extraction time. Reasoning:
an experienced reviewer can dismiss a false edge quickly, but can't review an
edge we never surfaced. A fuller, tagged list is more useful than a short,
opinionated one.

Rules produced:
- qualified constant used as a call receiver -> `constant_reference_call` (strong)
- qualified constant used any other way      -> `constant_reference_value` (weak)
- bare constants (`String`, `MAX_SIZE`)       -> NOT recorded yet (needs a
  whole-repo symbol table to tell app classes from built-ins/locals; documented
  limitation, revisit after directory scanning exists).

### `visit_constant_path_node` and NOT calling `super`
A `Foo::Bar` is a `ConstantPathNode`. Its only child is its parent chain
(`Foo`). If we descended into it we'd re-record sub-paths (`A::B` inside
`A::B::C`). So this visit method deliberately does not call `super`. We already
reconstruct the full name ourselves, so there's nothing useful below it.

### Avoiding double-counting with a "handled" set
The tree-walk naturally revisits nodes we already handled specifically — a
superclass, a mixin argument, a class's own name, a call receiver. To avoid
recording them a second time as generic references, we remember them:
```ruby
@handled = Set.new
def mark_handled(node) = (@handled << node.object_id if node)
def handled?(node)     = @handled.include?(node.object_id)
```
- **`object_id`** = a unique integer identity for an object. Prism returns the
  same node instance whether we reach it via `node.superclass` or via the walk,
  so their `object_id`s match — that's what makes this reliable.
- **`Set`** = a collection of unique items with fast membership checks
  (`include?`). Core in modern Ruby (no `require` needed).

### Extracting a pure function into a module
`constant_name` didn't depend on visitor state, so it moved out to its own
`ConstantName` module (also keeps the visitor under RuboCop's class-length
limit, and we'll reuse it in the Packwerk phase):
```ruby
module ConstantName
  module_function        # makes the methods callable as ConstantName.call(...)
  def call(node) = ...   # a pure function: same input -> same output, no state
end
```
- **`module_function`** turns the following methods into module-level methods
  you call on the module itself (`ConstantName.call(node)`), similar to a C#
  `static` helper class. Good for stateless utilities.

---

## Phase 2 — the CLI (Thor)

### Thor: building a command-line tool
```ruby
class CLI < Thor
  def self.exit_on_failure? = true          # exit non-zero on failure

  desc "scan PATH", "one-line help text"    # declares the command + help
  def scan(path)                            # the command body; PATH -> path
    ...
  end
end
CLI.start(ARGV)                             # parse ARGV and dispatch
```
- Each public method becomes a subcommand; `desc` gives its help text.
- Method arguments map to CLI arguments (`scan PATH` -> `def scan(path)`).
- `Thor` is what Rails' own `rails generate`/`rails new` are built on.
- Private methods (below `private`) are helpers, not commands.

### The executable: `exe/monolith-lens`
```ruby
#!/usr/bin/env ruby        # "shebang": run this file with ruby
require "monolith_lens/cli"
MonolithLens::CLI.start(ARGV)
```
- The gemspec's `bindir = "exe"` means files here become the gem's commands.
- Made runnable with `chmod +x exe/monolith-lens` (the Unix "executable" bit).
- Run it in dev with: `bundle exec exe/monolith-lens scan <path>`.

### stdout vs stderr (why we split them)
- **stdout** (`puts`) = the actual data (the JSON). Meant to be piped/parsed.
- **stderr** (`warn`) = human messages ("Scanned 10 files..."). Kept off stdout
  so `monolith-lens scan x > out.json` yields clean JSON, with the summary still
  visible in the terminal. This is standard Unix tool behaviour.

### The Scanner (core, not CLI)
```ruby
Dir.glob(File.join(@path, "**", "*.rb"))   # find every .rb recursively (**)
File.read(file)                             # read a file's text (never execute)
files.flat_map { |f| analyze_file(f) }      # map + flatten: each file -> many
                                            #   edges, combined into one list
Pathname.new(abs).relative_path_from(base)  # "billing/invoice.rb" not a long
                                            #   absolute path
```
- `flat_map` = `map` then flatten one level. Each file yields an array of edges;
  `flat_map` merges them into a single flat array.
- Kept in core (`MonolithLens::Static::Scanner`) so the CLI stays a thin shell;
  the CLI just calls the scanner and formats output.

### JSON output
```ruby
JSON.pretty_generate(edges.map { |e| { source: e.source, ... , evidence: e.evidence.map(&:to_h) } })
```
- `Data#to_h` turns an Evidence into a plain hash; symbols become strings in
  JSON (`:static` -> "static").

### Testing a CLI
- `Dir.mktmpdir { |dir| ... }` = make a throwaway temp directory (auto-deleted).
- Capture output by temporarily swapping `$stdout`/`$stderr` for a `StringIO`,
  then `JSON.parse` the captured string and assert on it.
- `expect { ... }.to raise_error(SystemExit)` verifies the "path not found ->
  exit 1" path.

---

## Phase 3 (Slice 1) — Rails app + Packwerk

### Rails in one paragraph
Rails is a web framework. `rails new` scaffolds a conventional app: `app/`
(your code: models, controllers, jobs, mailers), `config/` (settings), `db/`
(database schema/migrations), `bin/` (helper scripts like `bin/rails`), and a
`Gemfile`. It follows "convention over configuration" - if you name/place files
the expected way, Rails wires them up automatically. We generated a lean app
(skipped frontend/asset/deploy pieces we don't need) on SQLite.

### ActiveRecord (the "models" part) - preview
An ActiveRecord model is a Ruby class mapped to a database table. `class User <
ApplicationRecord` gives you `User.find`, `User.create`, associations, etc.,
without writing SQL. (C# analogy: an EF Core entity + DbSet, but far less
ceremony.) We'll write real ones in Slice 2.

### Autoloading (Zeitwerk)
Rails auto-loads classes by filename: `app/models/billing/invoice.rb` must
define `Billing::Invoice`. No `require` needed. We told Rails to also treat
`packs/<pack>/app/<layer>` as autoload roots, so a domain's code lives inside
its own pack but still follows the file-name-to-constant rule.

### Packwerk (the whole reason Rails is here)
Packwerk enforces boundaries between "packages" in a Rails monolith. Each
package is a directory with a `package.yml` declaring:
- `enforce_dependencies: true` - check references leaving this package.
- `dependencies:` - the OTHER packages this one is allowed to use.
`bin/packwerk check` reports references to packages you did NOT declare
(a "boundary violation"). `bin/packwerk validate` checks the config itself.

Key finding: **Packwerk requires the declared dependency graph to be acyclic** -
`validate` fails if package A declares B and B declares A. So real cycles show
up as *undeclared* references, not declarations. This shapes how we build the
intentional cycle (see docs/PLAN.md).

### Our four packages and their intended edges
- accounts -> (nothing); the base domain.
- billing -> accounts (declared, valid).
- notifications -> accounts (declared). Will also reference Billing WITHOUT
  declaring it -> intentional boundary violation.
- reporting -> accounts, billing (declared, valid). Billing will reference
  Reporting back WITHOUT declaring it -> undeclared reference that forms a cycle.

### Housekeeping
- `demo_app/` is a fixture, not gem code: excluded from the gem's `.rubocop.yml`
  and from `spec.files` in the gemspec (so `gem build` won't bundle a whole
  Rails app).
- `--skip-git` also skipped the Rails `.gitignore`; added one so logs, the
  SQLite DB, and tmp files are not committed.

---

## Phase 3 (Slice 2) — Rails building blocks

### Migrations
A migration is a versioned instruction for changing the database schema.
`bin/rails generate migration CreateUsers name:string email:string` writes a
timestamped file; `bin/rails db:migrate` runs it and updates `db/schema.rb`
(the current schema, which IS committed; the .sqlite3 file is NOT).

### ActiveRecord models
`class User < ApplicationRecord` maps a Ruby class to a DB table (namespaced
`Accounts::User` maps to the `users` table by default). You get `create!`,
`find`, `where(...).sum(...)`, etc. without writing SQL.
- **Validations**: `validates :email, presence: true` - checked before save;
  `record.valid?` / `create!` (bang raises on failure).
- **Callbacks**: `before_validation :normalize_email` runs your method
  automatically at that point in the lifecycle. Powerful but "spooky action at
  a distance" - a reason MonolithLens cares about hidden behaviour.

### Service objects
Plain Ruby classes with one job (e.g. `Billing::InvoiceProcessor#call`). Not a
Rails feature - just a convention for business logic that does not belong on a
model or controller. Keeps models thin.

### Background jobs (ActiveJob)
`class ReceiptJob < ApplicationJob` with a `perform(...)` method. Enqueue with
`ReceiptJob.perform_later(args)` - it runs asynchronously (later, on a queue).
- In tests we set `queue_adapter = :test`, which records enqueued jobs instead
  of running them, so we can assert on them.
- `have_enqueued_job(ReceiptJob).with(id)` - matcher: "this job got enqueued".
- `perform_enqueued_jobs { ... }` - actually run enqueued jobs inline.

### How the four scenarios map to code
- Valid dep: `Accounts::User.find` inside billing (billing declares accounts).
- Boundary violation: `Billing::Invoice.find` inside Notifications::InvoiceAlert
  (notifications does NOT declare billing).
- Cycle: `Reporting::RevenueSummary.record` inside Billing::InvoiceProcessor
  (billing does NOT declare reporting; reporting declares billing).
- Hidden runtime dep: `"Notifications::ReceiptJob".constantize.perform_later`
  - a string, not a constant, so static tools (Packwerk, our visitor) can't see
  it. This is the whole reason runtime tracing (Phase 5) exists.

### Base classes and the root package
`ApplicationRecord`/`ApplicationJob` live in the root package ".". Packs that
define models/jobs must declare a dependency on "." or Packwerk flags the base
class reference as a violation (framework noise, not a real boundary issue).

---

## Phase 4 — Packwerk integration (classifying edges)

### Reading package.yml
`YAML.safe_load_file(path)` parses a YAML file into Ruby hashes/arrays (the
"safe" variant refuses dangerous types). A package's name is its directory
path relative to the app root ("." for the root package). We read each
package's `dependencies` and `enforce_dependencies` flag.

### Resolving a constant to its package
An edge only knows the target's NAME (e.g. "Billing::Invoice"), not its file.
So the scan now also collects `definitions` (constant -> file). We build a
`constant => file` index, then map file -> owning package (nearest ancestor
package, longest path wins).

### enforce_dependencies matters
The root package has `enforce_dependencies: false`, so references FROM root
code (specs, config) are never violations - matching Packwerk. A cross-package
reference is only a violation when the source package enforces AND didn't
declare the target.

### The five classifications
- :external - target isn't in any package (a gem/framework base class)
- :internal - same package
- :unchecked - source doesn't enforce (e.g. root)
- :declared - cross-package and declared (fine)
- :boundary_violation - cross-package, enforced, undeclared

### Cycle detection with TSort
`TSort` is a Ruby stdlib module for topological sorting. Mix it in, define
`tsort_each_node` and `tsort_each_child`, and you get
`strongly_connected_components` for free. A strongly connected component with
more than one node IS a dependency cycle. This is the key differentiator:
Packwerk checks one reference at a time and can only say "undeclared
reference"; by building the whole package graph we can say "these packages
form a cycle".

### New Ruby seen here
- `Data.define(...)` nested inside a class (`PackageAnalysis::Result`).
- `Hash.new { |h, k| h[k] = [] }` - a Hash whose default for a missing key is a
  fresh empty array (handy for building adjacency lists).
- `each_with_object(Hash.new(0)) { ... }` - fold a collection into an
  accumulator; `Hash.new(0)` defaults missing keys to 0 (a counter).
- Anonymous block forwarding: `def tsort_each_node(&) ... each(&) end` passes
  the block through without naming it (Ruby 3.1+).
- `include TSort` - a *mixin*: pulls a module's methods into the class (this is
  what `include` does, and exactly the kind of dependency our analyzer detects).
