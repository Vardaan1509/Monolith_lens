# frozen_string_literal: true

RSpec.describe MonolithLens::Analysis::EvidenceMerger do
  def static_edge(source, target, rule: "constant_reference_call")
    MonolithLens::Edge.new(
      source: source, target: target, dependency_type: :constant_reference,
      evidence: [MonolithLens::Evidence.new(kind: :static, source_file: "a.rb", line: 1, rule: rule)]
    )
  end

  def runtime_edge(source, target)
    MonolithLens::Edge.new(
      source: source, target: target, dependency_type: :job_enqueue,
      evidence: [MonolithLens::Evidence.new(kind: :runtime, source_file: "a.rb", line: 1, rule: "job_enqueue")]
    )
  end

  def merge(static: [], runtime: [])
    described_class.merge(static_edges: static, runtime_edges: runtime)
  end

  it "marks an edge seen both statically and at runtime as confirmed, confidence 1.0" do
    merged = merge(static: [static_edge("A", "B")], runtime: [runtime_edge("A", "B")]).first

    expect(merged.classification).to eq(:static_and_runtime)
    expect(merged.confidence).to eq(1.0)
  end

  it "marks a static-only edge and scores it by rule strength" do
    merged = merge(static: [static_edge("A", "B", rule: "class_inheritance")]).first

    expect(merged.classification).to eq(:static_only)
    expect(merged.confidence).to eq(0.85)
  end

  it "marks a runtime-only edge (the hidden dependency) with confidence 0.7" do
    merged = merge(runtime: [runtime_edge("Billing::InvoiceProcessor", "Notifications::ReceiptJob")]).first

    expect(merged.classification).to eq(:runtime_only)
    expect(merged.confidence).to eq(0.7)
  end
end
