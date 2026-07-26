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
