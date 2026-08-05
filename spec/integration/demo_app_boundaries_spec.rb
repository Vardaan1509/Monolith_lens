# frozen_string_literal: true

# End-to-end boundary analysis of the demo app: MonolithLens should flag the
# same violations Packwerk does, AND additionally surface the dependency cycle
# (which Packwerk only reports as a plain undeclared reference).
RSpec.describe "Analyzing the demo app's package boundaries" do
  let(:app_root) { File.expand_path("../../demo_app", __dir__) }
  let(:result) do
    MonolithLens::Analysis::PackageAnalysis.call(
      code_path: File.join(app_root, "packs"), app_root: app_root
    )
  end

  def violations
    result.classified_edges.select { |ce| ce.classification == :boundary_violation }
  end

  it "flags exactly the two intentional boundary violations" do
    pairs = violations.map { |ce| [ce.source_package, ce.edge.target] }

    expect(pairs).to contain_exactly(
      ["packs/notifications", "Billing::Invoice"],
      ["packs/billing", "Reporting::RevenueSummary"]
    )
  end

  it "classifies the valid cross-package reference (billing -> accounts) as declared" do
    declared = result.classified_edges.any? do |ce|
      ce.source_package == "packs/billing" &&
        ce.edge.target == "Accounts::User" &&
        ce.classification == :declared
    end

    expect(declared).to be true
  end

  it "detects the billing <-> reporting cycle that Packwerk cannot name" do
    cycle = result.cycles.find { |component| component.sort == ["packs/billing", "packs/reporting"] }

    expect(cycle).not_to be_nil
  end
end
