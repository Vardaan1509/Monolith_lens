# frozen_string_literal: true

require "tmpdir"
require "fileutils"

RSpec.describe MonolithLens::Analysis::EdgeClassifier do
  def write_package(dir, name, contents)
    path = File.join(dir, name)
    FileUtils.mkdir_p(path)
    File.write(File.join(path, "package.yml"), contents)
  end

  def edge(source_file:, target:)
    MonolithLens::Edge.new(
      source: "Src", target: target, dependency_type: :constant_reference,
      evidence: [MonolithLens::Evidence.new(kind: :static, source_file: source_file, line: 1, rule: "r")]
    )
  end

  def definition(constant, file)
    MonolithLens::Static::Definition.new(constant: constant, source_file: file, line: 1)
  end

  it "classifies an undeclared cross-package reference as a boundary violation" do
    Dir.mktmpdir do |dir|
      write_package(dir, "packs/notifications", "enforce_dependencies: true\ndependencies: []\n")
      write_package(dir, "packs/billing", "enforce_dependencies: true\ndependencies: []\n")
      set = MonolithLens::Packwerk::PackageSet.load(dir)
      defs = [definition("Billing::Invoice", "packs/billing/app/models/billing/invoice.rb")]
      ref = edge(source_file: "packs/notifications/app/services/alert.rb", target: "Billing::Invoice")

      result = described_class.new(set, defs).classify(ref)

      expect(result.classification).to eq(:boundary_violation)
      expect(result.source_package).to eq("packs/notifications")
      expect(result.target_package).to eq("packs/billing")
    end
  end

  it "classifies a declared cross-package reference as declared" do
    Dir.mktmpdir do |dir|
      write_package(dir, "packs/billing", "enforce_dependencies: true\ndependencies:\n  - packs/accounts\n")
      write_package(dir, "packs/accounts", "enforce_dependencies: true\ndependencies: []\n")
      set = MonolithLens::Packwerk::PackageSet.load(dir)
      defs = [definition("Accounts::User", "packs/accounts/app/models/accounts/user.rb")]
      ref = edge(source_file: "packs/billing/app/services/x.rb", target: "Accounts::User")

      expect(described_class.new(set, defs).classify(ref).classification).to eq(:declared)
    end
  end

  it "classifies a reference to an unknown constant as external" do
    Dir.mktmpdir do |dir|
      write_package(dir, "packs/billing", "enforce_dependencies: true\ndependencies: []\n")
      set = MonolithLens::Packwerk::PackageSet.load(dir)
      ref = edge(source_file: "packs/billing/app/x.rb", target: "ActiveRecord::Base")

      expect(described_class.new(set, []).classify(ref).classification).to eq(:external)
    end
  end
end
