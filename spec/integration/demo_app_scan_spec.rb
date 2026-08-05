# frozen_string_literal: true

# End-to-end check: scan the bundled demo Rails app and confirm the static
# analyzer finds the dependencies we deliberately built into it - and, just as
# importantly, that it does NOT find the string-based hidden runtime dependency
# (which only runtime tracing can catch).
RSpec.describe MonolithLens::Static::Scanner, "against the demo app" do
  let(:packs_path) { File.expand_path("../../demo_app/packs", __dir__) }
  let(:edges) { described_class.scan(packs_path).edges }

  def edge?(source, target)
    edges.any? { |e| e.source == source && e.target == target }
  end

  it "detects the valid cross-domain dependency (billing -> accounts)" do
    expect(edge?("Billing::InvoiceProcessor", "Accounts::User")).to be true
  end

  it "detects the boundary-violating reference (notifications -> billing)" do
    expect(edge?("Notifications::InvoiceAlert", "Billing::Invoice")).to be true
  end

  it "detects both halves of the billing <-> reporting cycle" do
    expect(edge?("Billing::InvoiceProcessor", "Reporting::RevenueSummary")).to be true
    expect(edge?("Reporting::RevenueSummary", "Billing::Invoice")).to be true
  end

  it "does NOT detect the string-based hidden runtime dependency (billing -> notifications)" do
    edges_into_notifications = edges.select { |e| e.target.start_with?("Notifications::") }

    expect(edges_into_notifications).to be_empty
  end
end
