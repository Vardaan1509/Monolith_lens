# frozen_string_literal: true

require "monolith_lens/cli"
require "tmpdir"
require "json"
require "stringio"

RSpec.describe MonolithLens::CLI do
  # Run a block with $stdout and $stderr captured; return what was written to
  # stdout so we can assert on the JSON the command prints.
  def capture_stdout
    original_out = $stdout
    original_err = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_out
    $stderr = original_err
  end

  it "prints discovered edges as JSON to stdout" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "invoice.rb"), "class Invoice < BaseRecord; end")

      output = capture_stdout { described_class.start(["scan", dir]) }
      json = JSON.parse(output)

      expect(json.length).to eq(1)
      expect(json.first["source"]).to eq("Invoice")
      expect(json.first["target"]).to eq("BaseRecord")
      expect(json.first["dependency_type"]).to eq("inheritance")
      expect(json.first["evidence"].first["rule"]).to eq("class_inheritance")
    end
  end

  it "exits non-zero when the path does not exist" do
    expect { capture_stdout { described_class.start(["scan", "/no/such/path"]) } }
      .to raise_error(SystemExit)
  end
end
