# frozen_string_literal: true

# Capstone: a real change to the demo app, end to end. Changing Billing::Invoice
# should ripple to everything that depends on it, and recommend those specs.
RSpec.describe "Impact analysis on the demo app" do
  let(:app_root) { File.expand_path("../../demo_app", __dir__) }
  let(:scan) { MonolithLens::Static::Scanner.scan(File.join(app_root, "packs"), base: app_root) }
  let(:spec_files) { Dir.glob(File.join(app_root, "spec", "**", "*_spec.rb")) }
  let(:report) do
    MonolithLens::Analysis::ImpactAnalyzer.call(
      scan: scan,
      changed_files: ["packs/billing/app/models/billing/invoice.rb"],
      spec_files: spec_files
    )
  end

  it "identifies the changed constant" do
    expect(report.changed).to include("Billing::Invoice")
  end

  it "finds the constants that directly depend on the changed one" do
    expect(report.directly_affected).to contain_exactly(
      "Notifications::InvoiceAlert", "Reporting::RevenueSummary"
    )
  end

  it "reaches transitive dependents further out" do
    expect(report.transitively_affected).to include("Billing::InvoiceProcessor")
  end

  it "recommends the specs covering the affected code" do
    recommended = report.recommended_tests.map { |rec| File.basename(rec[:spec]) }

    expect(recommended).to include("invoice_alert_spec.rb", "revenue_summary_spec.rb")
  end

  it "reports a blast radius score weighting direct impact 3x over transitive" do
    # 2 direct (InvoiceAlert, RevenueSummary) * 3 + 1 transitive (InvoiceProcessor) * 1
    expect(report.blast_radius).to eq(7)
  end
end
