# frozen_string_literal: true

require "tmpdir"

RSpec.describe MonolithLens::Runtime::TraceIngester do
  def definition(constant, file)
    MonolithLens::Static::Definition.new(constant: constant, source_file: file, line: 1)
  end

  def write_trace(dir, *lines)
    path = File.join(dir, "trace.jsonl")
    File.write(path, lines.join("\n"))
    path
  end

  it "converts a job_enqueue event into a runtime edge, resolving the source constant" do
    Dir.mktmpdir do |dir|
      trace = write_trace(dir, '{"type":"job_enqueue","source_file":"a.rb","source_line":5,"target":"Notifications::ReceiptJob"}')
      defs = [definition("Billing", "a.rb"), definition("Billing::InvoiceProcessor", "a.rb")]

      edge = described_class.ingest(trace, definitions: defs).first

      expect(edge.source).to eq("Billing::InvoiceProcessor")
      expect(edge.target).to eq("Notifications::ReceiptJob")
      expect(edge.dependency_type).to eq(:job_enqueue)
    end
  end

  it "tags the evidence as runtime with the source line" do
    Dir.mktmpdir do |dir|
      trace = write_trace(dir, '{"type":"job_enqueue","source_file":"a.rb","source_line":5,"target":"X"}')

      evidence = described_class.ingest(trace, definitions: []).first.evidence.first

      expect(evidence.kind).to eq(:runtime)
      expect(evidence.line).to eq(5)
    end
  end

  it "returns no edges for a missing trace file" do
    expect(described_class.ingest("/no/such/trace.jsonl", definitions: [])).to eq([])
  end
end
