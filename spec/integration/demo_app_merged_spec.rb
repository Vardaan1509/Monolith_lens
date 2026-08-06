# frozen_string_literal: true

# Capstone: merge static + runtime evidence for the demo app and confirm the
# hidden runtime dependency survives as a runtime-only edge, while ordinary
# static references stay static-only.
RSpec.describe "Merging static and runtime evidence for the demo app" do
  let(:app_root) { File.expand_path("../../demo_app", __dir__) }
  let(:trace_path) { File.expand_path("../fixtures/demo_trace.jsonl", __dir__) }
  let(:scan) { MonolithLens::Static::Scanner.scan(File.join(app_root, "packs"), base: app_root) }
  let(:runtime_edges) do
    MonolithLens::Runtime::TraceIngester.ingest(trace_path, definitions: scan.definitions)
  end
  let(:merged) do
    MonolithLens::Analysis::EvidenceMerger.merge(static_edges: scan.edges, runtime_edges: runtime_edges)
  end

  it "keeps the hidden job dependency as a runtime-only edge" do
    edge = merged.find { |m| m.target == "Notifications::ReceiptJob" }

    expect(edge.classification).to eq(:runtime_only)
    expect(edge.confidence).to eq(0.7)
  end

  it "marks an ordinary static reference as static-only" do
    edge = merged.find { |m| m.source == "Reporting::RevenueSummary" && m.target == "Billing::Invoice" }

    expect(edge.classification).to eq(:static_only)
  end
end
