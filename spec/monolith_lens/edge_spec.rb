# frozen_string_literal: true

RSpec.describe MonolithLens::Edge do
  let(:evidence) do
    MonolithLens::Evidence.new(
      kind: :static,
      source_file: "app/billing/invoice_processor.rb",
      line: 5,
      rule: "constant_reference"
    )
  end

  it "exposes the dependency it was created with" do
    edge = described_class.new(
      source: "Billing::InvoiceProcessor",
      target: "Accounts::User",
      dependency_type: :constant_reference,
      evidence: [evidence]
    )

    expect(edge.source).to eq("Billing::InvoiceProcessor")
    expect(edge.target).to eq("Accounts::User")
    expect(edge.dependency_type).to eq(:constant_reference)
    expect(edge.evidence).to eq([evidence])
  end

  it "treats two edges with identical fields as equal" do
    a = described_class.new(
      source: "A", target: "B", dependency_type: :inheritance, evidence: [evidence]
    )
    b = described_class.new(
      source: "A", target: "B", dependency_type: :inheritance, evidence: [evidence]
    )

    expect(a).to eq(b)
  end
end
