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
