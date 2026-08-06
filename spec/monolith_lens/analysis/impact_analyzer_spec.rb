# frozen_string_literal: true

RSpec.describe MonolithLens::Analysis::ImpactAnalyzer do
  def edge(source, target)
    MonolithLens::Edge.new(
      source: source, target: target, dependency_type: :constant_reference,
      evidence: [MonolithLens::Evidence.new(kind: :static, source_file: "x", line: 1, rule: "r")]
    )
  end

  def defn(constant, file)
    MonolithLens::Static::Definition.new(constant: constant, source_file: file, line: 1)
  end

  def scan(edges:, definitions:)
    MonolithLens::Static::ScanResult.new(files_scanned: 0, edges: edges, definitions: definitions)
  end

  it "finds direct and transitive dependents of a changed file" do
    edges = [edge("Reporting::Summary", "Billing::Invoice"), edge("Dashboard", "Reporting::Summary")]
    defs = [
      defn("Billing::Invoice", "billing/invoice.rb"),
      defn("Reporting::Summary", "reporting/summary.rb"),
      defn("Dashboard", "dashboard.rb")
    ]

    report = described_class.call(
      scan: scan(edges: edges, definitions: defs), changed_files: ["billing/invoice.rb"], spec_files: []
    )

    expect(report.changed).to eq(["Billing::Invoice"])
    expect(report.directly_affected).to eq(["Reporting::Summary"])
    expect(report.transitively_affected).to eq(["Dashboard"])
  end

  it "recommends specs matching affected files by naming convention" do
    edges = [edge("Reporting::Summary", "Billing::Invoice")]
    defs = [defn("Billing::Invoice", "billing/invoice.rb"), defn("Reporting::Summary", "reporting/summary.rb")]
    specs = ["spec/billing/invoice_spec.rb", "spec/reporting/summary_spec.rb"]

    report = described_class.call(
      scan: scan(edges: edges, definitions: defs), changed_files: ["billing/invoice.rb"], spec_files: specs
    )

    expect(report.recommended_tests.map { |rec| rec[:spec] })
      .to contain_exactly("spec/billing/invoice_spec.rb", "spec/reporting/summary_spec.rb")
  end
end
