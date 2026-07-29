# frozen_string_literal: true

require "tmpdir"
require "fileutils"

RSpec.describe MonolithLens::Static::Scanner do
  def write(dir, relative, contents)
    path = File.join(dir, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, contents)
    path
  end

  def write_two_files(dir)
    write(dir, "billing/invoice.rb", "module Billing\n  class Invoice < BaseRecord\n  end\nend\n")
    write(dir, "accounts/user.rb", "module Accounts\n  class User\n    include Trackable\n  end\nend\n")
  end

  it "counts every ruby file found in the directory tree" do
    Dir.mktmpdir do |dir|
      write_two_files(dir)

      expect(described_class.scan(dir).files_scanned).to eq(2)
    end
  end

  it "aggregates edges found across all files into one list" do
    Dir.mktmpdir do |dir|
      write_two_files(dir)

      pairs = described_class.scan(dir).edges.map { |edge| [edge.source, edge.target] }

      expect(pairs).to contain_exactly(
        ["Billing::Invoice", "BaseRecord"],
        ["Accounts::User", "Trackable"]
      )
    end
  end

  it "reports file paths relative to the scanned directory in evidence" do
    Dir.mktmpdir do |dir|
      write(dir, "billing/invoice.rb", "class Invoice < BaseRecord; end")

      result = described_class.scan(dir)

      expect(result.edges.first.evidence.first.source_file).to eq("billing/invoice.rb")
    end
  end

  it "can scan a single file" do
    Dir.mktmpdir do |dir|
      path = write(dir, "thing.rb", "class Thing < Base; end")

      result = described_class.scan(path)

      expect(result.files_scanned).to eq(1)
      expect(result.edges.first.target).to eq("Base")
    end
  end

  it "returns no edges for a directory with no ruby files" do
    Dir.mktmpdir do |dir|
      result = described_class.scan(dir)

      expect(result.files_scanned).to eq(0)
      expect(result.edges).to be_empty
    end
  end
end
