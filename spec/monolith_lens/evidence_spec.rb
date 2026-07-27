# frozen_string_literal: true

RSpec.describe MonolithLens::Evidence do
  it "exposes the fields it was created with" do
    evidence = described_class.new(
      kind: :static,
      source_file: "app/models/user.rb",
      line: 12,
      rule: "class_inheritance"
    )

    expect(evidence.kind).to eq(:static)
    expect(evidence.source_file).to eq("app/models/user.rb")
    expect(evidence.line).to eq(12)
    expect(evidence.rule).to eq("class_inheritance")
  end

  it "treats two instances with identical fields as equal" do
    a = described_class.new(kind: :static, source_file: "x.rb", line: 1, rule: "r")
    b = described_class.new(kind: :static, source_file: "x.rb", line: 1, rule: "r")

    expect(a).to eq(b)
  end
end
