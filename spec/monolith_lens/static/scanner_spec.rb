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

  it "aggregates edges across all ruby files in a directory tree" do
    Dir.mktmpdir do |dir|
      write(dir, "billing/invoice.rb", <<~RUBY)
        module Billing
          class Invoice < BaseRecord
          end
        end
      RUBY
      write(dir, "accounts/user.rb", <<~RUBY)
        module Accounts
          class User
            include Trackable
          end
        end
      RUBY

      result = described_class.scan(dir)

      expect(result.files_scanned).to eq(2)
      pairs = result.edges.map { |edge| [edge.source, edge.target] }
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
