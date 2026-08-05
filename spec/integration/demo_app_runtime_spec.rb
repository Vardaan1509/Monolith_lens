# frozen_string_literal: true

# The hidden runtime dependency: Billing enqueues Notifications::ReceiptJob via
# a string, so static analysis can't see it. Ingesting a runtime trace (with
# the demo app's own scan definitions) recovers it as a runtime edge - the
# core payoff of combining static and runtime evidence.
RSpec.describe "Ingesting a runtime trace of the demo app" do
  let(:app_root) { File.expand_path("../../demo_app", __dir__) }
  let(:trace_path) { File.expand_path("../fixtures/demo_trace.jsonl", __dir__) }
  let(:scan) { MonolithLens::Static::Scanner.scan(File.join(app_root, "packs"), base: app_root) }
  let(:runtime_edges) do
    MonolithLens::Runtime::TraceIngester.ingest(trace_path, definitions: scan.definitions)
  end

  it "recovers the billing -> notifications dependency that static analysis missed" do
    edge = runtime_edges.find { |e| e.target == "Notifications::ReceiptJob" }

    expect(edge.source).to eq("Billing::InvoiceProcessor")
    expect(edge.evidence.first.kind).to eq(:runtime)
  end

  it "confirms the static scan does NOT contain that dependency" do
    static_targets = scan.edges.map(&:target)

    expect(static_targets).not_to include("Notifications::ReceiptJob")
  end
end
