# frozen_string_literal: true

require "tmpdir"
require "fileutils"

RSpec.describe MonolithLens::Packwerk::PackageSet do
  def write_package(dir, name, contents)
    path = name == "." ? dir : File.join(dir, name)
    FileUtils.mkdir_p(path)
    File.write(File.join(path, "package.yml"), contents)
  end

  it "reads a package's declared dependencies and enforcement flag" do
    Dir.mktmpdir do |dir|
      write_package(dir, "packs/billing", "enforce_dependencies: true\ndependencies:\n  - packs/accounts\n")

      billing = described_class.load(dir).packages.find { |p| p.name == "packs/billing" }

      expect(billing.enforce_dependencies).to be true
      expect(billing.dependencies).to eq(["packs/accounts"])
    end
  end

  it "maps a file to its owning package, most specific winning" do
    Dir.mktmpdir do |dir|
      write_package(dir, ".", "enforce_dependencies: false\n")
      write_package(dir, "packs/billing", "enforce_dependencies: true\n")
      set = described_class.load(dir)

      expect(set.package_for("packs/billing/app/models/billing/invoice.rb").name).to eq("packs/billing")
      expect(set.package_for("app/models/application_record.rb").name).to eq(".")
    end
  end

  it "answers whether one package declares another" do
    Dir.mktmpdir do |dir|
      write_package(dir, "packs/billing", "dependencies:\n  - packs/accounts\n")
      write_package(dir, "packs/accounts", "dependencies: []\n")
      set = described_class.load(dir)
      billing = set.package_for("packs/billing/x.rb")
      accounts = set.package_for("packs/accounts/x.rb")

      expect(set.declares?(billing, accounts)).to be true
      expect(set.declares?(accounts, billing)).to be false
    end
  end
end
